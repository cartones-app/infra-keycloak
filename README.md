# infra-keycloak

Keycloak para la **gestión de cartones**. Trae el realm `cartones` y un theme
custom aplicado al login, cuenta y emails.

Vive separado del repo del backend para poder levantarlo de forma independiente
y deployearlo en su propio container/VPS sin acoplarlo al ciclo de vida de la
aplicación.

## Modelo de ramas

| Rama | Uso | Despliegue |
|------|-----|-----------|
| `master` | Producción (default) | Build de la imagen para VPS |
| `develop` | Staging | Railway escucha esta rama → `https://keycloak-staging-085a.up.railway.app/realms/cartones` |
| `next` | Integración (rama de trabajo) | Solo CI |

Repo **público** (era privado; se cambió para habilitar branch protection en el
plan free de GitHub). Branch protection activa en `master` y `develop`:
required status check `check` (workflow `branch-policy.yml`), no force-push, no
deletes. `branch-policy.yml` además bloquea PRs que no sigan el flujo
`next → develop → master`.

## Estructura

```
infra-keycloak/
├── Dockerfile                          ← imagen propia (themes horneados + kc.sh build)
├── docker-entrypoint.sh                ← substituye placeholders del template al boot, deposita en import/
├── docker-compose.yml                  ← producción (build local, start --optimized --import-realm)
├── docker-compose.local.yml            ← override dev (start-dev + import-realm + theme hot-reload)
├── keycloak/
│   ├── realm-cartones.json.example         ← template con placeholders __FRONTEND_HOST__ / __CLIENT_SECRET__
│   └── themes/cartones/                    ← theme custom (hereda de keycloak.v2)
└── .env.example                            ← variables requeridas
```

> El template `realm-cartones.json.example` se commitea. NO existe un
> `realm-cartones.json` resuelto en el repo: el entrypoint lo genera al boot
> a partir del template + variables de entorno y lo escribe en
> `/opt/keycloak/data/import/`. El template **no incluye** claves `_*` (Keycloak
> rechaza el import si las encuentra); los seed users que estaban como
> `_local_users_seed` quedaron como referencia en este README, no en el JSON.

## Preparar el realm

El template `keycloak/realm-cartones.json.example` se commitea con
placeholders. `docker-entrypoint.sh` corre al boot del container y:

1. Sustituye `__FRONTEND_HOST__` y `__CLIENT_SECRET__` con los valores de las
   variables de entorno.
2. Escribe el JSON resuelto en `/opt/keycloak/data/import/`.
3. Delega a `kc.sh` con el `CMD` por defecto del Dockerfile
   (`start --optimized --import-realm`), que importa idempotentemente.

Si `FRONTEND_HOST` o `CLIENT_SECRET` no están seteadas, el entrypoint no falla
— asume que hay un volumen montado con un realm pre-resuelto (caso dev local
sin substitución, ver más abajo).

Variables consumidas por el entrypoint:

- `FRONTEND_HOST` — host del frontend SIN el `http(s)://`. Dev: `localhost:3000`.
  Prod: `cartones.tudominio.com`.
- `CLIENT_SECRET` — secret del client `frontend` (debe coincidir con
  `AUTH_KEYCLOAK_SECRET` del frontend). Generar con `openssl rand -hex 32`.

### Seed users

El template no incluye usuarios. Para staging Railway se crearon dos via Admin
API tras el primer boot:

- `admin` / `admin123` — rol `ADMIN`
- `distribuidor` / `distribuidor123` — rol `DISTRIBUIDOR`

En staging también se bajó `passwordPolicy` a vacío (el template trae 12 chars
+ complejidad — innecesario para un entorno de testing). Prod mantiene la
policy original.

## Desarrollo local

```bash
cp .env.example .env
$EDITOR .env  # completar KEYCLOAK_ADMIN_PASSWORD, KC_DB_PASSWORD,
              # FRONTEND_HOST=localhost:3000 y CLIENT_SECRET
              # (KC_HOSTNAME se pisa a "localhost" desde el override local — no editar)

docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
```

- Consola admin: <http://localhost:8080/admin> (user `admin`, password del `.env`).
- El entrypoint resuelve el template con `FRONTEND_HOST` / `CLIENT_SECRET` del
  `.env` y `--import-realm` lo importa al primer boot. Idempotente: si el realm
  ya existe lo skipea. Para reimportar tras editar el template:
  `docker compose ... down -v && ... up -d` (borra el volumen del Postgres del
  Keycloak y reimporta limpio).
- Theme `cartones` activo en el realm. Cache off en dev: editás los archivos
  en `keycloak/themes/cartones/` y se reflejan al recargar la página de login
  (sin reiniciar el container).

## Producción

```bash
cp .env.example .env
# completar con valores reales: KC_HOSTNAME=keycloak.tudominio.com,
# FRONTEND_HOST=cartones.tudominio.com, CLIENT_SECRET=<openssl rand -hex 32>

docker compose build keycloak
docker compose up -d
```

- Detrás de proxy reverso (Cloudflare Tunnel → nginx-proxy en el VPS).
- Imagen propia con themes horneados y `kc.sh build` ya ejecutado.
  Cambios al theme requieren rebuild: `docker compose build keycloak && docker compose up -d keycloak`.
- El `CMD` por defecto del Dockerfile es `start --optimized --import-realm`. El
  entrypoint resuelve el template y deposita el JSON en
  `/opt/keycloak/data/import/` antes de delegar a `kc.sh`. Idempotente.

### Staging (Railway)

`develop` se buildea automáticamente y deploya en
`https://keycloak-staging-085a.up.railway.app/realms/cartones`. Postgres
adjunto, `FRONTEND_HOST` y `CLIENT_SECRET` como Railway variables. Los users
seed se crean via Admin API tras el primer boot (ver sección "Seed users").

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
# Debe coincidir con `secret` del client `frontend` en realm-cartones.json.
# Para dev local con el realm seed: dev-only-frontend-secret-no-usar-en-prod
AUTH_KEYCLOAK_SECRET=<mismo valor que __CLIENT_SECRET__ del realm>
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
   `KC_HEALTH_ENABLED`, `KC_METRICS_ENABLED`, `KC_CACHE=ispn`. Las options
   runtime (`KC_PROXY_HEADERS`, `KC_HTTP_ENABLED`, `KC_HOSTNAME`, etc.) NO
   van en el build — se setean en el `environment` del compose.
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
