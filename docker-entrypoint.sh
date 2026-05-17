#!/usr/bin/env bash
# =============================================================================
# Entrypoint que prepara el realm-cartones.json a partir del template y
# delega en kc.sh con los args que recibió el container.
# =============================================================================
# Por qué existe:
#   - El realm de prod/staging contiene placeholders (__FRONTEND_HOST__,
#     __CLIENT_SECRET__) que NO se pueden hornear en la imagen (acoplan la
#     build a un dominio/secreto concretos). En Railway no hay manera cómoda
#     de montar el JSON resuelto como volumen.
#   - Este script substituye los placeholders al boot desde env vars y deja
#     el resultado en /opt/keycloak/data/import/, donde KC lo encuentra
#     automáticamente cuando se pasa `--import-realm`.
#   - `--import-realm` es idempotente: si el realm ya existe en la DB, KC
#     lo skipea sin tocar nada. Para forzar reimport hay que rotar la DB.
#
# Env vars REQUERIDAS:
#   FRONTEND_HOST   p.ej. cartones-app-web-staging.vercel.app (sin https://)
#   CLIENT_SECRET   secret del client `frontend` (igual al del frontend en NextAuth)
#
# Env var OPCIONAL:
#   SKIP_REALM_RENDER=1  no renderiza el template (útil para depurar; si está
#                        seteado, KC arranca sin import — el realm tiene que
#                        existir ya en la DB).
# =============================================================================
set -euo pipefail

TEMPLATE_PATH="/opt/keycloak/realm-template/realm-cartones.json.example"
OUTPUT_DIR="/opt/keycloak/data/import"
OUTPUT_PATH="${OUTPUT_DIR}/realm-cartones.json"

render_realm() {
    if [[ ! -f "$TEMPLATE_PATH" ]]; then
        echo "[entrypoint] WARN: template no encontrado en $TEMPLATE_PATH — skipeando render." >&2
        return 0
    fi

    # Si no hay vars, asumimos que el caller (típicamente dev local) monta
    # un realm-cartones.json ya resuelto en $OUTPUT_DIR. No fail-fast: KC
    # importa lo que encuentre. Si nada se montó, KC arranca sin realm
    # cartones (sólo `master`) y el operador ve el problema en /admin.
    if [[ -z "${FRONTEND_HOST:-}" || -z "${CLIENT_SECRET:-}" ]]; then
        echo "[entrypoint] FRONTEND_HOST/CLIENT_SECRET no seteadas — no se renderiza el realm." >&2
        echo "[entrypoint] (Esperado en dev local con volumen montado.)" >&2
        return 0
    fi

    mkdir -p "$OUTPUT_DIR"

    # sed con delimitador `|` para evitar conflictos con `/` de URLs.
    # Quotamos las vars por las dudas; no esperamos caracteres raros pero
    # blindamos por si CLIENT_SECRET trae `&` (interpretado por sed).
    sed \
        -e "s|__FRONTEND_HOST__|${FRONTEND_HOST}|g" \
        -e "s|__CLIENT_SECRET__|${CLIENT_SECRET}|g" \
        "$TEMPLATE_PATH" > "$OUTPUT_PATH"

    echo "[entrypoint] realm renderizado en $OUTPUT_PATH (FRONTEND_HOST=${FRONTEND_HOST})"
}

if [[ "${SKIP_REALM_RENDER:-0}" != "1" ]]; then
    render_realm
else
    echo "[entrypoint] SKIP_REALM_RENDER=1 — no se renderiza el realm."
fi

exec /opt/keycloak/bin/kc.sh "$@"
