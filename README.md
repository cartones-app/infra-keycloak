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
│   ├── realm-cartones.local.json           ← realm DEV (users seed, http localhost)
│   ├── realm-cartones.prod.json.example    ← template PROD (placeholders, sin users)
│   ├── realm-cartones.prod.json            ← (gitignoreado) realm real de prod, customizado
│   └── themes/cartones/                    ← theme custom (hereda de keycloak.v2)
└── .env.example                            ← variables requeridas
```

## Desarrollo local

```bash
cp .env.example .env
# editá .env con KEYCLOAK_ADMIN_PASSWORD y KC_DB_PASSWORD

docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
```

- Consola admin: <http://localhost:8080/admin> (user `admin`, password del `.env`).
- El override local importa `keycloak/realm-cartones.local.json` automáticamente
  al primer boot (idempotente). Trae users de demo (`admin/admin123`,
  `distribuidor/distribuidor123`, contraseñas temporales).
- Theme `cartones` activo en el realm. Cache off en dev: editás los archivos
  en `keycloak/themes/cartones/` y se reflejan al recargar la página de login
  (sin reiniciar el container).

## Producción

```bash
cp .env.example .env
# completar con valores reales, KC_HOSTNAME=keycloak.tudominio.com

# 1) Preparar el realm de prod desde el template
cp keycloak/realm-cartones.prod.json.example keycloak/realm-cartones.prod.json
# editar realm-cartones.prod.json: reemplazar __FRONTEND_HOST__, sumar users
# desde la UI admin después del primer boot, etc. Este archivo está gitignoreado.

# 2) Buildear la imagen propia y levantar
docker compose build keycloak
docker compose up -d
```

- Detrás de proxy reverso (Cloudflare Tunnel → nginx-proxy en el VPS).
- Imagen propia con themes horneados y `kc.sh build` ya ejecutado.
  Cambios al theme requieren rebuild: `docker compose build keycloak && docker compose up -d keycloak`.
- El realm se importa **una vez** manualmente. Copiar el archivo al container e importar:

```bash
docker compose cp keycloak/realm-cartones.prod.json keycloak:/tmp/realm.json
docker compose exec keycloak /opt/keycloak/bin/kc.sh import \
  --file /tmp/realm.json --override true
```

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
