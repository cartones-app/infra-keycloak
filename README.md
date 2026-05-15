# infra-keycloak

Keycloak para la **gestión de cartones**. Trae el realm `cartones` y un theme
custom aplicado al login, cuenta y emails.

Vive separado del repo del backend para poder levantarlo de forma independiente
y deployearlo en su propio container/VPS sin acoplarlo al ciclo de vida de la
aplicación.

## Estructura

```
infra-keycloak/
├── docker-compose.yml          ← producción (start --optimized + Postgres dedicado)
├── docker-compose.local.yml    ← override dev (start-dev + import-realm + theme hot-reload)
├── keycloak/
│   ├── realm-cartones.json     ← realm con clients, roles, theme aplicado
│   └── themes/cartones/        ← theme custom (hereda de keycloak.v2)
├── secrets_store/              ← secretos para producción
└── .env.example                ← variables requeridas
```

## Desarrollo local

```bash
cp .env.example .env
# editá .env con KEYCLOAK_ADMIN_PASSWORD y KC_DB_PASSWORD

docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
```

- Consola admin: <http://localhost:8080/admin> (user `admin`, password del `.env`).
- Realm `cartones` se importa automáticamente al primer boot (idempotente).
- Theme `cartones` activo en el realm. Cache off en dev: editás los archivos
  en `keycloak/themes/cartones/` y se reflejan al recargar la página de login
  (sin reiniciar el container).

## Producción

```bash
cp .env.example .env
# completar con valores reales, KC_HOSTNAME=keycloak.tudominio.com

docker compose up -d
```

- Detrás de proxy reverso (Cloudflare Tunnel → nginx-proxy en el VPS).
- Sin `start-dev`, sin import-realm automático.
- El realm se importa **una vez** manualmente vía la consola admin, o:

```bash
docker compose exec keycloak /opt/keycloak/bin/kc.sh import \
  --file /opt/keycloak/data/import/realm-cartones.json \
  --override true
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

Para desarrollo local con todo levantado en localhost, ambos repos siguen
trayendo Keycloak en su `docker-compose.yml`. Este repo es para el deploy
real / un dev que quiera el Keycloak corriendo aparte.

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

## Producción: build optimizado del theme

Para que `start --optimized` funcione con el theme custom, ejecutar **una vez**
después de cambios al theme:

```bash
docker compose exec keycloak /opt/keycloak/bin/kc.sh build
docker compose restart keycloak
```

Alternativa más limpia (pendiente para el primer deploy a prod): armar un
`Dockerfile` propio que copie `keycloak/themes/` al directorio del image y
haga `kc.sh build` durante el build.
