# yeGamo API and Database Implementation Plan

> **Execution:** Subagent-Driven Development. Cada tarea tiene un límite de archivos, una interfaz verificable y un commit independiente.

**Goal:** Implementar la primera superficie ejecutable del API NestJS y el esquema PostgreSQL/PostGIS de yeGamo, alineados con el contrato OpenAPI v1.1.1 y las decisiones aceptadas.

**Architecture:** Monolito modular NestJS stateless con módulos por dominio, núcleo de dominio independiente del framework, gateway de proveedores y worker en el mismo código. PostgreSQL + PostGIS usa migraciones SQL versionadas como fuente de verdad; Prisma Client cubre CRUD tipado y `pg` queda restringido a PostGIS, locking y concurrencia justificados.

**Prerequisites:** `context/plans/FOUNDATIONS-CLOSEOUT.md`, `context/adr/`, `context/specs/11_API_SPEC.md`, `context/specs/12_OPENAPI.yaml`, `context/specs/13_DATABASE_SPEC.md`, `context/specs/14_SCHEMA.sql`, `api/contracts/openapi.yaml`.

## Invariantes

- Todas las rutas HTTP viven bajo `/v1` y se alinean con `api/contracts/openapi.yaml`.
- Las reglas de negocio no viven en controllers, pipes ni widgets.
- Ninguna respuesta expone DTOs de proveedores.
- `LIVE` requiere fuente autorizada y `observedAt` reciente; una posición inferida es `ESTIMATED`.
- El guest mode no requiere cuenta; guest migration es explícita, transaccional, idempotente y auditable.
- No se almacenan contraseñas ni coordenadas precisas por defecto.
- `DemoTransitProvider` solo se habilita en desarrollo, pruebas o demo marcada.
- Los SQL aplicables viven en `api/db/migrations/`; cada migration debe poder ejecutarse desde cero y desde la versión anterior.

## Task 1: Scaffold NestJS y composición del monolito

**Files:**

- Create: `api/package.json`, `api/tsconfig.json`, `api/tsconfig.build.json`, `api/nest-cli.json`
- Create: `api/.env.example`, `api/src/main.ts`, `api/src/app.module.ts`
- Create: `api/src/config/**`, `api/src/shared/**` (solo bootstrap/config/health/trace/error interfaces)
- Create: `api/test/health.e2e-spec.ts`, `api/test/jest-e2e.json`

**Steps:**

1. Configurar TypeScript estricto, scripts `start:dev`, `build`, `test`, `test:e2e`, `lint`, `db:migrate`, `db:verify` y dependencias NestJS/config/validation.
2. Componer `ConfigModule` global, `ValidationPipe` global (`whitelist`, `forbidNonWhitelisted`, `transform`), prefijo global `/v1`, filtro de errores canónico e interceptor `X-Trace-Id`/`traceId`.
3. Crear health check sin depender de proveedores; la respuesta debe coincidir con `HealthResponse`.
4. Dejar tokens/interfaces para repositorios y gateway, sin implementar lógica de dominio en el bootstrap.
5. Probar que la app levanta, rechaza campos desconocidos y devuelve error canónico.

**Verification:** `npm ci`, `npm run build`, `npm test`, `npm run test:e2e`.

## Task 2: Migraciones SQL PostgreSQL/PostGIS y runner

**Files:**

- Create: `api/db/migrations/0001_extensions_and_migration_log.sql`
- Create: `api/db/migrations/0002_identity_and_preferences.sql`
- Create: `api/db/migrations/0003_transit_catalog.sql`
- Create: `api/db/migrations/0004_journeys_and_active_journeys.sql`
- Create: `api/db/migrations/0005_routines_alerts_notifications.sql`
- Create: `api/db/migrations/0006_reliability_and_community.sql`
- Create: `api/db/migrations/0007_indexes_constraints_retention.sql`
- Create: `api/db/seeds/README.md`, `api/db/seeds/development.sql`
- Create: `api/src/shared/database/migrate.ts`, `api/src/shared/database/verify-schema.ts`
- Create: `api/prisma/schema.prisma`, `api/prisma/README.md`
- Create: `api/test/database/migrations.e2e-spec.ts`

**Steps:**

1. Crear `postgis` y el log de migrations con checksum, timestamps y lock advisory. El runner aplica en orden, dentro de transacción por migration, y falla ante checksum alterado.
2. Implementar UUID, `timestamptz`, enums/checks/FKs, políticas explícitas de `ON DELETE`, `geography(Point,4326)` para lugares/paradas y `geometry(LineString,4326)` para trazas.
3. Cubrir tablas de identidad/preferencias, catálogo transitario/feed versions, planes/opciones/legs/eventos, viajes activos, rutinas/alertas/notificaciones/entregas, reliability/provider health y community post-MVP según la spec.
4. Añadir índices B-tree y GiST para búsquedas por usuario, tiempo, frescura y proximidad; demostrar `ST_DWithin` en verificación.
5. Aislar seeds demo bajo un flag explícito y no insertar `RutaYa`, `Metrovia GTFS` ni fuentes simuladas como datos productivos.
6. Mantener `prisma/schema.prisma` como artefacto derivado para Prisma Client y documentar la dirección de sincronización SQL → Prisma.
7. Probar migración desde cero, segunda ejecución idempotente, rollback operacional documentado y upgrade desde una fixture de versión anterior.

**Verification:** `npm run db:migrate`, `npm run db:verify`, tests de migración con PostgreSQL/PostGIS y comparación de tablas/índices contra `context/specs/13_DATABASE_SPEC.md`.

## Task 3: Persistencia tipada y provider gateway

**Files:**

- Create: `api/src/shared/database/prisma.service.ts`, `api/src/shared/database/database.module.ts`
- Create: `api/src/provider-gateway/domain/**`, `api/src/provider-gateway/application/**`, `api/src/provider-gateway/adapters/demo-transit.provider.ts`, `api/src/provider-gateway/mappers/**`
- Create: `api/src/provider-gateway/provider-gateway.module.ts`
- Create: `api/test/provider-gateway/**`

**Steps:**

1. Exponer Prisma Client por DI para CRUD; cualquier `$queryRaw` debe estar en un adapter/repositorio con comentario de necesidad PostGIS/locking/concurrencia.
2. Definir modelos canónicos para `TransitPlan`, `TransitStop`, `JourneyOption`, `JourneyLeg`, `DataQuality`, `ProviderHealthSnapshot` y errores de proveedor.
3. Definir interfaces `TransitPlannerProvider`, `GeocodingProvider`, `VehiclePositionProvider`, `TrafficIncidentProvider`.
4. Implementar `DemoTransitProvider` solo para `NODE_ENV` de desarrollo/test/demo y con `providerDisplayName` marcado como demo; producción sin adapter devuelve `UNAVAILABLE`/`DEGRADED`.
5. Implementar timeout, fallback, freshness y circuit state sin filtrar DTOs externos.

**Verification:** tests unitarios de mapper, bloqueo de demo en producción, timeout/fallback y rechazo de `LIVE` sin fuente/timestamp.

## Task 4: Módulos API MVP y casos de uso

**Files:**

- Create/update only under `api/src/modules/{auth,users,preferences,places,transit,journey-planning,active-journeys,commute-profiles,leave-alerts,notifications,privacy}/**`
- Create: `api/src/composition/**`
- Create: `api/test/contract/**`, `api/test/unit/**`

**Steps:**

1. Implementar controllers/DTOs/ports/mappers para las operaciones del contrato, sin agregar rutas fuera de OpenAPI.
2. Implementar `GET /me`, guest migration, dispositivos, preferencias, exportación y eliminación con JWT OIDC configurable; el API no implementa password auth.
3. Implementar places/nearby/transit y planificación con ranking, margen, ventana de llegada y estados de datos honestos.
4. Implementar active journeys, commutes, leave alerts y notifications con idempotencia y transición de estados.
5. Mantener dominio independiente de NestJS/Prisma/pg; usar composition para conectar adapters y repositorios.
6. Agregar contract tests que comparen status/body/headers con `api/contracts/openapi.yaml` y pruebas de autorización.

**Verification:** `npm run test:contract`, `npm test`, prueba manual de `curl` para salud, planificación, guest migration y una operación idempotente.

## Task 5: Worker, observabilidad y seguridad operativa

**Files:**

- Create: `api/src/jobs/**`, `api/src/worker.ts`
- Create: `api/src/shared/observability/**`, `api/src/shared/auth/**`, `api/src/shared/idempotency/**`
- Create: `api/test/jobs/**`, `api/test/security/**`
- Modify: `api/src/app.module.ts`, `api/src/main.ts`, `api/package.json`

**Steps:**

1. Crear entrypoint worker en el mismo código para rutinas, alertas, deliveries, retención, métricas y refresh autorizado de feeds.
2. Implementar validación JWT/JWKS por configuración, claims mínimos, audience/issuer y autorización por usuario.
3. Implementar idempotency store transaccional con request hash, estado, respuesta y expiración.
4. Emitir trace ID, latencia, provider, fallback y data state sin secretos ni coordenadas precisas.
5. Probar reintentos, doble ejecución, expiración y aislamiento de jobs.

**Verification:** tests de seguridad/idempotencia/jobs y `npm run build`.

## Task 6: Gate API/database y handoff

**Files:**

- Create: `api/README.md` update with runbook
- Create: `api/docs/API-DATABASE-BASELINE.md`
- Create: `api/test/README.md`
- Modify: `context/plans/FOUNDATIONS-CLOSEOUT.md`

**Steps:**

1. Ejecutar desde un PostgreSQL/PostGIS limpio: migrations, seeds demo marcados, build, unit, contract, e2e y verify schema.
2. Confirmar que cada path OpenAPI tiene controller o está explícitamente post-MVP/feature-flagged.
3. Confirmar que cada tabla de `context/specs/13_DATABASE_SPEC.md` tiene migration, índice/constraint y prueba de existencia.
4. Registrar commits, comandos, resultados, límites conocidos y el siguiente plan `flutter-app`.

**Verification:** gate reproducible documentado y `git diff --check` limpio.

## Orden de ejecución Subagent-Driven

1. Task 1 y Task 2 en paralelo, porque sus superficies son `api/src`/config y `api/db`/Prisma.
2. Revisar ambos resultados; Task 3 depende de la conexión de Task 1 y las tablas/cliente de Task 2.
3. Task 4 depende de Task 3 y del contrato ya publicado.
4. Task 5 puede comenzar cuando exista composición de Task 4, con revisión separada de jobs/auth.
5. Task 6 solo se cierra después de PostgreSQL/PostGIS real o un entorno reproducible equivalente.
