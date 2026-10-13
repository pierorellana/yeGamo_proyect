# yeGamo Local Tunnel Data Vertical Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hacer operativa la vertical local de yeGamo con PostgreSQL/PostGIS, catálogo demo, planificación de desarrollo y acceso desde el iPhone mediante un túnel HTTPS de VS Code.

**Architecture:** El API conservará el monolito modular NestJS. Un repositorio de infraestructura implementará `TransitReadPort` con consultas PostGIS parametrizadas; el proveedor demo seguirá aislado en `ProviderGateway` y solo se habilitará explícitamente en desarrollo. Flutter conservará el estado invitado local, consultará cercanía solo con coordenadas válidas y recibirá la URL pública por `--dart-define`.

**Tech Stack:** Node.js 20.19.4, NestJS 11, Prisma Client 6, PostgreSQL + PostGIS + pgcrypto, TypeScript, Flutter/Dart, `http`, `provider`, Jest/Supertest y Flutter Test.

## Global Constraints

- No realizar commits nuevos hasta instrucción explícita del usuario.
- `api/db/migrations/` es la fuente ejecutable del esquema SQL.
- `context/specs/` y `docs/superpowers/specs/2026-10-13-yegamo-local-tunnel-data-vertical-design.md` definen el comportamiento.
- No versionar `api/.env`, URLs de túnel, tokens, credenciales ni datos de usuarios.
- No publicar datos demo como `LIVE`; el catálogo sintético usa `DEGRADED` y `observedAt: null`.
- No guardar ubicación precisa; las coordenadas se usan en memoria para la consulta.
- No modificar el contrato OpenAPI sin actualizar contrato, ejemplo y prueba correspondiente.
- Preservar los cambios existentes no relacionados en `.claude/` y `yegamo_app/.fvm/`.

---

### Task 1: Preparar PostgreSQL/PostGIS y el entorno de desarrollo

**Files:**
- Modify: `api/.env.example` solo si hace falta documentar una variable adicional.
- Modify: `api/README.md` para documentar el arranque local reproducible.

**Interfaces:**
- Consumes: las ocho migraciones existentes y el seed explícito de desarrollo.
- Produces: una base `yegamo` accesible por `DATABASE_URL`, con PostGIS/pgcrypto y el catálogo demo cargado.

- [ ] **Step 1: Inspeccionar PostgreSQL local**

  Run:

  ```bash
  brew services list
  brew list --versions postgresql postgresql@16 postgresql@17 postgis 2>/dev/null || true
  pg_isready
  ```

  Expected: identificar una instalación utilizable; si no existe servidor activo, instalar mediante Homebrew la versión disponible de PostgreSQL y PostGIS antes de continuar.

- [ ] **Step 2: Arrancar PostgreSQL y crear la base de desarrollo**

  Usar el servicio instalado, sin borrar clústeres existentes:

  ```bash
  brew services start postgresql@16
  createdb yegamo 2>/dev/null || true
  pg_isready -d yegamo
  ```

  Si Homebrew ofrece otra versión instalada, usar ese nombre de servicio. El criterio de pase es que `pg_isready -d yegamo` responda `accepting connections`.

- [ ] **Step 3: Crear configuración local ignorada**

  Crear `api/.env` con:

  ```dotenv
  NODE_ENV=development
  PORT=3000
  APP_VERSION=1.1.1
  DATABASE_URL=postgresql://localhost:5432/yegamo
  ```

  Comprobar `git check-ignore api/.env`; no incluir credenciales de producción.

- [ ] **Step 4: Aplicar y verificar migraciones**

  Run from `api/`:

  ```bash
  PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm run db:migrate
  PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm run db:verify
  ```

  Expected: ocho versiones aplicadas, extensiones `postgis` y `pgcrypto` disponibles, y verificación de tablas/columnas espaciales exitosa.

- [ ] **Step 5: Cargar el fixture demo explícitamente**

  Run from workspace root:

  ```bash
  PGOPTIONS='-c yegamo.seed_mode=development' \
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f api/db/seeds/development.sql
  ```

  Expected: dos paradas y una ruta demo; nunca ejecutar este seed en producción.

- [ ] **Step 6: Confirmar el catálogo**

  ```bash
  psql "$DATABASE_URL" -c "SELECT count(*) AS stops FROM transit_stops;"
  psql "$DATABASE_URL" -c "SELECT count(*) AS routes FROM transit_routes;"
  ```

  Expected para una base limpia: `stops = 2` y `routes = 1`.

- [ ] **Step 7: Documentar el arranque**

  En `api/README.md`, documentar `api/.env`, migración, seed, `db:verify` y el arranque con `DEMO_PROVIDER_ENABLED=true`, sin incluir secretos.

- [ ] **Step 8: Verificar la tarea**

  ```bash
  git diff --check
  git status --short api/.env api/README.md
  ```

  Expected: `.env` ignorado y solo la documentación aparece como cambio.

### Task 2: Conectar el catálogo de transporte del API a PostGIS

**Files:**
- Create: `api/src/transit/infrastructure/prisma-transit.repository.ts`
- Modify: `api/src/transit/transit.module.ts`
- Modify: `api/src/transit/domain/transit.ports.ts` solo si el tipo existente requiere alineación.
- Modify: `api/test/transit/transit.spec.ts`
- Create: `api/test/transit/transit-repository.e2e-spec.ts`

**Interfaces:**
- Consumes: `PrismaService`, `TransitReadPort`, `transit_stops`, `transit_routes`, `transit_agencies` y `route_stops`.
- Produces: `PrismaTransitReadRepository` con `nearbyStops(input)`, `departures(stopId)` y `route(routeId)`.

- [ ] **Step 1: Escribir el test de integración**

  Crear un e2e omitido si no existe `DATABASE_URL`. Con base disponible, construir el repositorio, consultar `nearbyStops({ lat: -2.155, lon: -79.895, radiusM: 3000 })`, comprobar dos paradas, distancia no negativa y `dataState === 'DEGRADED'`; consultar la ruta demo y su agencia; comprobar que un radio de 50 metros no incluye la parada destino.

- [ ] **Step 2: Ejecutar el test en rojo**

  ```bash
  cd api
  PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm test -- --runInBand --watchman=false test/transit/transit-repository.e2e-spec.ts
  ```

  Expected antes de implementar: falla porque `PrismaTransitReadRepository` aún no existe.

- [ ] **Step 3: Implementar consultas parametrizadas**

  Mantener PostGIS dentro del repositorio y usar `Prisma.sql` con `$queryRaw`. La consulta de cercanía debe usar `ST_DWithin` para el filtro y `ST_Distance` para ordenar; debe proyectar `id`, `name`, longitud, latitud y distancia. Filtrar `canonical_status = 'ACTIVE'` y ordenar por distancia/nombre.

  Mapear las paradas a `TransitStop` con `dataState: 'DEGRADED'`. Para `route`, hacer `LEFT JOIN` con la agencia y mapear ruta inexistente a `null`. Para `departures`, devolver `[]` porque el esquema actual no tiene horarios; no crear ETA sintética.

- [ ] **Step 4: Registrar el repositorio con NestJS**

  Importar `DatabaseModule`, registrar `PrismaTransitReadRepository` y cambiar el proveedor del token a:

  ```typescript
  {
    provide: TRANSIT_READ_PORT,
    useClass: PrismaTransitReadRepository,
  }
  ```

  Mantener `TransitService` dependiente del token, no de Prisma.

- [ ] **Step 5: Ajustar pruebas HTTP**

  Conservar validaciones 422 y éxito canónico con fake. Mantener una prueba de 503 solo para un fake explícitamente no disponible, no para la implementación operativa del módulo.

- [ ] **Step 6: Ejecutar pruebas focalizadas**

  ```bash
  cd api
  PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm test -- --runInBand --watchman=false test/transit
  PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm run typecheck
  ```

### Task 3: Corregir Home para invitado y coordenadas válidas

**Files:**
- Modify: `yegamo_app/lib/modules/home/services/home_repository.dart`
- Modify: `yegamo_app/lib/modules/onboarding/task_five_app.dart`
- Modify: `yegamo_app/test/modules/home/home_test.dart`
- Modify: `yegamo_app/test/modules/test_support.dart` solo para reutilizar transporte capturado.

**Interfaces:**
- Consumes: `ApiClient`, `ConnectivityService`, `LocalStorage`, `LocationService` y `SessionManager`.
- Produces: `HomeSnapshot` sin 422 por coordenadas ausentes ni 401 causado por una sesión invitada.

- [ ] **Step 1: Escribir pruebas de invitado**

  Agregar prueba con posición `(-2.17, -79.9)` que compruebe que la única petición remota de Home usa `/v1/transit/stops/nearby` con `lat`, `lon` y `radiusM=1000`. Agregar prueba sin posición que compruebe que no se solicita nearby y que se conserva un estado de permiso/sin cobertura, sin error de validación.

- [ ] **Step 2: Ejecutar pruebas en rojo**

  ```bash
  cd yegamo_app
  fvm flutter test test/modules/home/home_test.dart
  ```

  Expected: el constructor aún no recibe las nuevas dependencias o Home sigue llamando rutas sin query.

- [ ] **Step 3: Implementar carga condicional**

  Actualizar `HomeRepository` para comprobar conectividad, obtener `currentPosition()` una vez, incluir nearby solo con posición válida y omitir favoritos/notificaciones cuando `session.isGuest`. Mantener estados offline/degraded/error/empty sin convertir una respuesta parcial válida en error global.

  Actualizar `TaskFiveScope` para pasar `LocationService` y `SessionManager` a `HomeRepository`. No cambiar el comportamiento local de Saved, Notifications y Commutes.

- [ ] **Step 4: Formatear y verificar Flutter**

  ```bash
  cd yegamo_app
  fvm dart format lib/modules/home/services/home_repository.dart lib/modules/onboarding/task_five_app.dart test/modules/home/home_test.dart test/modules/test_support.dart
  fvm flutter test test/modules/home/home_test.dart test/modules/nearby/nearby_test.dart
  fvm flutter analyze
  ```

### Task 4: Documentar y ejecutar el túnel del iPhone

**Files:**
- Modify: `api/README.md`
- Modify: `yegamo_app/README.md`
- Create: `.vscode/tasks.json` solo si no existe una tarea reutilizable y no se guarda la URL pública.

**Interfaces:**
- Consumes: `api/.env`, `DEMO_PROVIDER_ENABLED`, VS Code Ports y `AppConfig.fromEnvironment()`.
- Produces: comandos reproducibles para levantar API y Flutter con una URL HTTPS externa.

- [ ] **Step 1: Documentar el arranque del API**

  ```bash
  NODE_ENV=development DEMO_PROVIDER_ENABLED=true \
  PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH \
  npm run start:dev
  ```

  Expected: compilación sin errores y escucha en el puerto 3000.

- [ ] **Step 2: Documentar VS Code Ports**

  Abrir Ports, reenviar `3000`, cambiar visibilidad a `Public`, copiar la URL HTTPS y mantenerla solo durante la sesión de desarrollo.

- [ ] **Step 3: Arrancar Flutter en el iPhone**

  ```bash
  export YEGAMO_TUNNEL_URL='https://URL_PUBLICA_COPIADA_DE_VS_CODE'
  cd yegamo_app
  fvm flutter run -d 00008140-001461680A7B801C \
    --dart-define=YEGAMO_ENV=development \
    --dart-define=YEGAMO_DEMO_DATA=true \
    --dart-define=YEGAMO_API_BASE_URL="$YEGAMO_TUNNEL_URL"
  ```

  La URL se sustituye solo en la terminal y no se guarda en archivos.

- [ ] **Step 4: Verificar desde datos móviles**

  En el iPhone, conceder ubicación si corresponde, abrir Nearby y probar el origen manual `-2.17, -79.90`; comprobar Home, Nearby y Planner. Registrar `X-Trace-Id` ante cualquier error.

### Task 5: Verificación completa sin commit

**Files:**
- Modify: ninguno salvo correcciones derivadas de las pruebas anteriores.

**Interfaces:**
- Consumes: resultados de Tasks 1–4.
- Produces: working tree verificable y reporte final con comandos, limitaciones y pasos de túnel.

- [ ] **Step 1: Checks API**

  ```bash
  cd api
  PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm run typecheck
  PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm run build
  PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm test -- --runInBand --watchman=false
  ```

- [ ] **Step 2: Checks Flutter**

  ```bash
  cd yegamo_app
  fvm flutter analyze
  fvm flutter test
  ```

- [ ] **Step 3: Checks HTTP**

  ```bash
  curl -i http://127.0.0.1:3000/v1/health
  curl -i 'http://127.0.0.1:3000/v1/transit/stops/nearby?lat=-2.17&lon=-79.9&radiusM=1000'
  ```

  Expected: health `200`, nearby `200` con paradas `DEGRADED`.

- [ ] **Step 4: Revisar cambios y secretos**

  ```bash
  cd /Users/jorge/Desktop/yeGamo
  git diff --check
  git status --short
  git diff -- api yegamo_app docs/superpowers/plans/2026-10-13-yegamo-local-tunnel-data-vertical-plan.md
  ```

  Confirmar que no aparecen `api/.env`, tokens, URLs reales de túnel ni artefactos generados. No ejecutar `git commit`.
