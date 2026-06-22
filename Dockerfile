# =============================================================================
# Imagen Keycloak custom para cartones-app.
# =============================================================================
# Multi-stage:
#   1. builder: trae la base oficial, copia themes/providers, corre `kc.sh build`
#      con la config fija de prod (DB postgres, health, metrics, proxy headers).
#      Esto pre-compila el augmented JAR para arrancar con `start --optimized`.
#   2. runtime: imagen final mínima. Hereda el /opt/keycloak ya buildeado,
#      declara HEALTHCHECK, usa USER 1000 (no-root) y deja `start --optimized`
#      como CMD por defecto.
#
# Build:
#   docker build -t cartones-app/keycloak:26.1 .
#
# Variables que afectan el build (cambiarlas implica rebuildear la imagen):
#   - KC_DB (fijada a postgres acá)
#   - features habilitadas (--features)
#   - themes/providers copiados
# Variables runtime (NO requieren rebuild): KC_HOSTNAME, KC_DB_URL, credenciales,
# KC_PROXY_HEADERS, etc. — se pasan vía environment del compose.
# =============================================================================

ARG KEYCLOAK_VERSION=26.1.4

# ----------------------------------------------------------------------------
# Stage 1: builder
# ----------------------------------------------------------------------------
FROM quay.io/keycloak/keycloak:${KEYCLOAK_VERSION} AS builder

# Solo opciones de BUILD acá (las que influyen en `kc.sh build`). En KC 26:
#   db, features, health-enabled, metrics-enabled, cache, log, tls, transaction-xa-enabled.
# KC_HTTP_ENABLED y KC_PROXY_HEADERS son RUNTIME — se setean en el compose, no
# acá (si se los pone en build no afectan el JAR, solo confunden).
ENV KC_DB=postgres \
    KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=true \
    KC_CACHE=ispn

# Themes custom (login/account/email). Se copian ANTES del build para que
# `kc.sh build` los detecte y cachee. Si se agregan SPIs propios (providers/),
# va el mismo patrón:
#   COPY --chown=keycloak:keycloak providers/ /opt/keycloak/providers/
COPY --chown=keycloak:keycloak keycloak/themes/ /opt/keycloak/themes/

# Compila la versión optimizada del server con la config de arriba.
# Tras esto, runtime arranca con `start --optimized` (saltea el auto-build).
RUN /opt/keycloak/bin/kc.sh build

# ----------------------------------------------------------------------------
# Stage 2: runtime
# ----------------------------------------------------------------------------
FROM quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}

LABEL org.opencontainers.image.title="cartones-app-keycloak" \
    org.opencontainers.image.description="Keycloak 26.1 pre-built para cartones-app (realm cartones, theme custom)." \
    org.opencontainers.image.source="https://github.com/cartones-app/infra-keycloak" \
    org.opencontainers.image.licenses="Apache-2.0" \
    org.opencontainers.image.vendor="ncoders.solutions"

# Copia el server ya buildeado del stage anterior.
COPY --from=builder --chown=keycloak:keycloak /opt/keycloak/ /opt/keycloak/

# Template del realm + entrypoint que lo renderiza al boot. El template trae
# placeholders __FRONTEND_HOST__ / __CLIENT_SECRET__ que se resuelven desde
# env vars en runtime (ver docker-entrypoint.sh). El resultado va a
# /opt/keycloak/data/import/ donde KC lo descubre cuando se pasa
# `--import-realm`. Idempotente: si el realm ya existe en DB, se skipea.
COPY --chown=keycloak:keycloak keycloak/realm-cartones.json.example /opt/keycloak/realm-template/realm-cartones.json.example
COPY --chown=keycloak:keycloak docker-entrypoint.sh /opt/keycloak/docker-entrypoint.sh
# Permisos exec sin depender de cómo viene el bit en el host (Windows/WSL
# muchas veces lo pierden); además garantiza que el USER 1000 lo pueda correr.
RUN chmod 755 /opt/keycloak/docker-entrypoint.sh

# La base oficial ya corre como UID 1000 (keycloak). Lo dejamos explícito para
# que sea evidente en `docker inspect` y para escáneres de seguridad.
USER 1000

# Healthcheck contra el management port (9000), endpoint /health/ready de KC.
# La imagen oficial no incluye curl/wget; usamos /dev/tcp (extensión de bash).
# Forma exec con bash explícito para no depender de que `/bin/sh` apunte a bash
# si la base cambia (UBI9 hoy lo apunta, pero blindamos por las dudas).
HEALTHCHECK --interval=15s --timeout=10s --start-period=90s --retries=10 \
    CMD ["bash", "-c", "exec 3<>/dev/tcp/localhost/9000 && printf 'GET /health/ready HTTP/1.0\\r\\nHost: localhost\\r\\n\\r\\n' >&3 && head -n 1 <&3 | grep -q '200'"]

# El entrypoint renderiza el realm y luego exec'a `kc.sh` con los args del CMD.
# Default a producción + import idempotente. El override local lo pisa con
# `start-dev --import-realm` (sigue funcionando, el entrypoint es transparente).
ENTRYPOINT ["/opt/keycloak/docker-entrypoint.sh"]
CMD ["start", "--optimized", "--import-realm"]
