# yeGamo API

El API de yeGamo será un monolito modular NestJS con REST/JSON versionado bajo
`/v1`. Esta superficie contiene el contrato HTTP y, en las siguientes fases,
los módulos de aplicación, el worker y las migraciones SQL.

## Contrato y límites

- El contrato canónico es [`contracts/openapi.yaml`](contracts/openapi.yaml).
- Las reglas funcionales provienen de [`../context/specs/11_API_SPEC.md`](../context/specs/11_API_SPEC.md).
- Las respuestas exponen modelos canónicos; nunca exponen DTOs propietarios de
  proveedores.
- `LIVE` solo se puede publicar con una fuente autorizada, `observedAt` y
  frescura suficiente. El backend decide `dataState` y calidad.
- El API no almacena contraseñas ni persiste ubicación precisa sin consentimiento.
- Los datos de demostración del prototipo no son fuentes productivas.

## Verificación local

Desde `api/` y con Node.js `>=20`:

```bash
npm ci
npm run typecheck
npm run build
npm test -- --runInBand --watchman=false
npm run db:verify
```

`npm run db:verify` necesita un `DATABASE_URL` apuntando a PostgreSQL con
PostGIS y `pgcrypto`. Sin esa variable el comando debe fallar explícitamente;
no se considera un pase simulado. La suite de migraciones también queda
omitida por Jest cuando no existe esa precondición.

## Arranque local con PostgreSQL/PostGIS

El archivo `api/.env` es local y está ignorado por git. Para una instalación
de Homebrew con PostgreSQL escuchando en `127.0.0.1:5432`, usa:

```dotenv
NODE_ENV=development
PORT=3000
APP_VERSION=1.1.1
DATABASE_URL=postgresql://127.0.0.1:5432/yegamo
NOMINATIM_ENABLED=true
NOMINATIM_USER_AGENT=yeGamo-local-dev/1.0
OVERPASS_ENABLED=true
OVERPASS_BASE_URL=https://overpass-api.de/api/interpreter
OVERPASS_TIMEOUT_MS=20000
OVERPASS_CACHE_TTL_MS=900000
```

Desde `api/`, carga esas variables y aplica el esquema:

```bash
set -a
source .env
set +a
npm run db:migrate
npm run db:verify
```

El runner de migraciones no ejecuta datos demo automáticamente. Para cargar el
catálogo sintético solo en desarrollo:

```bash
PGOPTIONS='-c yegamo.seed_mode=development' \
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/seeds/development.sql
```

El API puede arrancar con el proveedor demo explícito:

La primera consulta de paradas lee PostgreSQL/PostGIS. Si no hay cobertura
local, el API consulta Overpass y, si sus instancias públicas están saturadas,
usa el fallback acotado de la API de mapa de OpenStreetMap. Luego guarda las
paradas OSM con referencias idempotentes y vuelve a leerlas. Las paradas se
muestran como `DEGRADED` porque OSM aporta ubicación, no horarios ni posiciones
de buses en vivo.

```bash
NODE_ENV=development \
NOMINATIM_ENABLED=true \
NOMINATIM_USER_AGENT='yeGamo-local-dev/1.0' \
OVERPASS_ENABLED=true \
OVERPASS_BASE_URL='https://overpass-api.de/api/interpreter' \
npm run start:dev
```

## Variables de entorno (referencia)

Ninguna lleva secretos en el repositorio; `api/.env` está ignorado por git.

| Variable | Uso | Por defecto |
|---|---|---|
| `NODE_ENV` | `production` desactiva el proveedor demo y exige configuración explícita | `development` |
| `DATABASE_URL` | PostgreSQL + PostGIS (obligatoria para persistencia) | — |
| `OIDC_ISSUER_URL`, `OIDC_AUDIENCE`, `OIDC_JWKS_URL` | Validación de JWT de cuenta. Sin ellos las rutas de cuenta responden 401 `IDENTITY=UNAVAILABLE` | — |
| `DEMO_PROVIDER_ENABLED` | `true` solo fuera de producción: planificador fixture (tramos a pie, `DEGRADED`) | `false` |
| `OVERPASS_*`, `NOMINATIM_*` | Descubrimiento de paradas y geocodificación OSM (ver ADR-010) | ver arriba |
| `WORKERS_ENABLED` | `true` activa el scheduler en proceso (avisos, entrega, salud de proveedores, retención) | `false` |
| `WORKER_ALERTS_INTERVAL_MS`, `WORKER_DELIVERY_INTERVAL_MS`, `WORKER_HEALTH_INTERVAL_MS`, `WORKER_RETENTION_INTERVAL_MS` | Periodicidad de cada job (mín. 1000) | 30 s / 60 s / 5 min / 1 h |
| `RATE_LIMIT_PER_MINUTE` | Solicitudes por IP y minuto (`0` desactiva) | `120` |
| `RATE_LIMIT_PLAN_PER_MINUTE` | Límite de `POST /v1/journeys/plan` | `20` |

Producción: migrar con `npm run db:migrate` (checksum verificado y bloqueo
consultivo), validar con `npm run db:verify`, y comprobar la persistencia con
`DATABASE_URL=… npm run test:e2e`.

## Acceso desde un iPhone por datos móviles

En VS Code, abre la vista **Ports**, reenvía el puerto `3000`, cambia la
visibilidad a **Public** y copia la URL HTTPS generada. La app Flutter ya
acepta esa URL por configuración de compilación; no la guardes en el repositorio:

```bash
export YEGAMO_TUNNEL_URL='https://URL_PUBLICA_COPIADA_DE_VS_CODE'
cd ../yegamo_app
fvm flutter run -d 00008140-001461680A7B801C \
  --dart-define=YEGAMO_ENV=development \
  --dart-define=YEGAMO_DEMO_DATA=false \
  --dart-define=YEGAMO_REAL_MAP=true \
  --dart-define=YEGAMO_API_BASE_URL="$YEGAMO_TUNNEL_URL"
```

La URL debe ser HTTPS y el proceso NestJS debe permanecer activo mientras se
usa el túnel. El cliente Flutter nativo no requiere CORS.

## Datos demo y proveedores

Nominatim es el proveedor público de geocodificación habilitado en desarrollo
por defecto. En producción debe habilitarse explícitamente con un
`NOMINATIM_USER_AGENT` propio. Flutter inicia la búsqueda después de 500 ms
sin cambios y con al menos tres caracteres; el gateway conserva la caché y
respeta como mínimo una solicitud por segundo. Overpass se limita a una caja
geográfica, tiene caché de quince minutos y no se consulta desde Flutter. El
fallback de la API de mapa se limita a 1 km para respetar el límite de volumen
de ese endpoint público.
En producción las capacidades dependientes responden `503
PROVIDER_UNAVAILABLE`, `dataState: UNAVAILABLE` y `X-Trace-Id`. El adapter
`DemoTransitProvider` sólo se puede activar de forma explícita fuera de
producción:

```bash
NODE_ENV=development \
DEMO_PROVIDER_ENABLED=true \
NOMINATIM_ENABLED=true \
NOMINATIM_USER_AGENT='yeGamo-local-dev/1.0' \
npm run start:dev
```

No usar esa bandera como configuración productiva ni presentar sus respuestas
como `LIVE`; para el flujo real del MVP se debe usar
`OVERPASS_ENABLED=true`.

## Organización

```text
api/
├── contracts/       # frontera HTTP versionada y ejemplos
├── db/migrations/   # fuente de verdad SQL en el plan de datos
├── src/              # monolito modular NestJS
└── test/             # pruebas unitarias, integración y contrato
```

La implementación no debe agregar un controller, estado de error o header sin
actualizar primero el contrato, el ejemplo afectado y la prueba de contrato en
la misma corrida. El inventario ejecutable está en
`test/contracts/openapi-contract.spec.ts`; las capacidades de comunidad
publicadas para compatibilidad están marcadas `post-mvp` y no se cuentan como
runtime implementado.
