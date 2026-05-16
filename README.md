# infra-keycloak

Keycloak para la **gestión de cartones**. Trae el realm `cartones` y un theme
custom aplicado al login, cuenta y emails.

Vive separado del repo del backend para poder levantarlo de forma independiente
y deployearlo en su propio container/VPS sin acoplarlo al ciclo de vida de la
aplicación.

## Estructura

```
infra-keycloak/
├── Dockerfile                          ← imagen propia (themes horneados + kc.sh build)
├── docker-compose.yml                  ← producción (build local, start --optimized)
├── docker-compose.local.yml            ← override dev (start-dev + import-realm + theme hot-reload)
├── keycloak/
│   ├── realm-cartones.json.example         ← template genérico (placeholders, hardening de prod)
│   ├── realm-cartones.json                 ← (gitignoreado) realm resuelto del template
│   └── themes/cartones/                    ← theme custom (hereda de keycloak.v2)
└── .env.example                            ← variables requeridas
```

## Preparar el realm

El archivo `keycloak/realm-cartones.json` es gitignoreado — cada operador lo
genera localmente desde el template, con los valores reales del entorno
(secret del client, hostname del frontend, hardening según dev/prod).

```bash
cp keycloak/realm-cartones.json.example keycloak/realm-cartones.json
$EDITOR keycloak/realm-cartones.json
```

Reemplazar:

- `__CLIENT_SECRET__` — secret del client `frontend` (debe coincidir con
  `AUTH_KEYCLOAK_SECRET` del frontend). Generar con `openssl rand -hex 32`,
  o un string fijo si todos los devs comparten realm.
- `__FRONTEND_HOST__` — host del frontend SIN el `http(s)://`.
  Dev: `localhost:3000`. Prod: `cartones.tudominio.com`.

Customizaciones por entorno (ver `_dev_setup` / `_prod_setup` en el template):

- **Dev**: agregar `"sslRequired": "none"` al objeto raíz; opcionalmente sumar
  users seed (el template trae el bloque `_local_users_seed` listo para pegar
  dentro del array `"users"`).
- **Prod**: dejar `sslRequired: "external"`, no commitear, crear users desde
  la UI admin tras el primer boot.

## Desarrollo local

```bash
cp .env.example .env
$EDITOR .env  # KEYCLOAK_ADMIN_PASSWORD, KC_DB_PASSWORD, KC_HOSTNAME=localhost

docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
```

- Consola admin: <http://localhost:8080/admin> (user `admin`, password del `.env`).
- El override local importa `keycloak/realm-cartones.json` automáticamente
  al primer boot. Idempotente: si el realm ya existe lo skipea. Para reimportar
  tras editar el JSON: `docker compose ... down -v && ... up -d` (borra
  el volumen del Postgres del Keycloak y reimporta limpio).
- Theme `cartones` activo en el realm. Cache off en dev: editás los archivos
  en `keycloak/themes/cartones/` y se reflejan al recargar la página de login
  (sin reiniciar el container).

## Producción

```bash
cp .env.example .env
# completar con valores reales, KC_HOSTNAME=keycloak.tudominio.com

# 1) Preparar el realm (ver sección anterior). El archivo realm-cartones.json
#    queda gitignoreado con los valores reales y el secret del client.

# 2) Buildear la imagen propia y levantar
docker compose build keycloak
docker compose up -d
```

- Detrás de proxy reverso (Cloudflare Tunnel → nginx-proxy en el VPS).
- Imagen propia con themes horneados y `kc.sh build` ya ejecutado.
  Cambios al theme requieren rebuild: `docker compose build keycloak && docker compose up -d keycloak`.
- El compose de prod NO monta el realm como volumen (a diferencia del local).
  El realm se importa **una vez** manualmente tras levantar:

```bash
docker compose cp keycloak/realm-cartones.json keycloak:/tmp/realm.json
docker compose exec keycloak /opt/keycloak/bin/kc.sh import \
  --file /tmp/realm.json --override true
# Limpiar el archivo del container tras importar (el realm queda persistido en la DB).
docker compose exec keycloak rm /tmp/realm.json
```

### Hardening post-bootstrap

Tras el primer arranque, Keycloak ya creó el admin en la base y **no vuelve a
leer** `KC_BOOTSTRAP_ADMIN_USERNAME` / `KC_BOOTSTRAP_ADMIN_PASSWORD`. Esas
variables quedan visibles en `docker inspect` y en herramientas de
observabilidad indefinidamente. Conviene vaciarlas en el `.env` después del
primer boot:

```bash
# .env
KEYCLOAK_ADMIN_USER=admin
KEYCLOAK_ADMIN_PASSWORD=   # vaciar tras primer boot — la password ya está en la DB
```

Si rotás la password del admin desde la UI, también acordate de actualizar
(o limpiar) el `.env` para que no quede una credencial vieja expuesta.

## Cómo apuntar la app de cartones a este Keycloak

En el backend (`backend-AppWeb/.env`):

```bash
KEYCLOAK_ISSUER_URI=https://keycloak.tudominio.com/realms/cartones
KEYCLOAK_JWK_SET_URI=https://keycloak.tudominio.com/realms/cartones/protocol/openid-connect/certs
```

En el frontend (`cartones-app-web/.env`):

```bash
AUTH_KEYCLOAK_ID=frontend
AUTH_KEYCLOAK_SECRET=public-client
AUTH_KEYCLOAK_ISSUER=https://keycloak.tudominio.com/realms/cartones
```

El backend ya no trae Keycloak en su `docker-compose.yml` — para correr todo
en local hay que levantar primero este repo (`docker compose -f docker-compose.yml
-f docker-compose.local.yml up -d`) y después el backend.

## Theme custom

`keycloak/themes/cartones/` hereda de `keycloak.v2` y solo sobreescribe
CSS variables. Beneficios:

- Cuando Keycloak hace upgrade del template oficial, lo absorbemos gratis
  (no tocamos los `.ftl`).
- Branding cambia en un solo archivo
  (`keycloak/themes/cartones/login/resources/css/login.css`).

Para cambiar colores / radius / fuente: editar las CSS variables al top del
archivo. Las clases más específicas solo redefinen lo que la CSS variable no
puede expresar (gradientes, transforms).

## Roles del realm

- `ADMIN` — operaciones de negocio + panel admin + métricas.
- `DISTRIBUIDOR` — operaciones del día a día.

## Imagen propia

El `Dockerfile` arma una imagen multi-stage que:

1. Parte de `quay.io/keycloak/keycloak:26.1.4` (versión pineada vía `ARG`).
2. Copia `keycloak/themes/` y corre `kc.sh build` con `KC_DB=postgres`,
   `KC_HEALTH_ENABLED`, `KC_METRICS_ENABLED`, `KC_PROXY_HEADERS=xforwarded`.
3. En runtime queda lista para `start --optimized` (CMD por defecto), corre
   como `USER 1000` y declara un `HEALTHCHECK` contra `:9000/health/ready`.

Resultado: arranque rápido en prod (sin auto-build), themes horneados y
config inmutable. Vars que afectan el build (rebuildear si cambian):
themes/providers, `KC_DB`, `--features`. Vars runtime (sin rebuild):
`KC_HOSTNAME`, credenciales DB, `KC_PROXY_HEADERS`, etc.

```bash
docker compose build keycloak           # tras cambiar themes o el Dockerfile
docker compose up -d keycloak
```
