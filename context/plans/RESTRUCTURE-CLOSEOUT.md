# yeGamo — cierre de reestructuración integral

**Fecha:** 2026-10-12  
**Estado:** cierre verificable con precondiciones externas pendientes  
**Alcance:** sólo Task 8 del plan integral; sin commit ni push

## Resultado ejecutivo

Se conserva la topología física `context/`, `yegamo_app/` y `api/`. La App
dispone de un catálogo test-only de las 17 rutas baseline y los 9 estados UX,
checks de semántica/responsive, y un flujo de integración con transporte y
reloj falsos. El API tiene validación contractual contra los controllers,
incluido el estado autenticado de proveedores. No se añadieron proveedores
autorizados ni se convirtió ningún fixture en dato productivo.

No se generaron imágenes golden: el proyecto no tiene runner/configuración de
goldens ni baseline visual versionada. Se validan semántica, wrapping, safe
areas, targets y reduced motion con pruebas de widgets estables.

## Matriz de requisitos

| Requisito | Implementación | Evidencia | Estado |
|---|---|---|---|
| 17 pantallas exactas | `AppRoutes.baseline` y `test/fixtures/prototype_states.dart` | `prototype_states_test.dart`, `navigation_test.dart` | Verificado |
| 9 estados UX exactos | `UxState`/`RemoteStateView` y catálogo test-only | `prototype_states_test.dart`, `prototype_semantics_test.dart` | Verificado |
| Datos honestos | gateway providerless, `DataQualityBadge`, errores canónicos | tests de gateway, widgets e integración sin `LIVE` | Verificado en tests |
| Frontera HTTP | `api/contracts/openapi.yaml`, controllers y filtros | `openapi-contract.spec.ts` | Verificado |
| Sin proveedor autorizado | adapters vacíos por defecto y `PROVIDER_UNAVAILABLE` | provider gateway + HTTP tests | Verificado |
| Privacidad | consentimiento de ubicación, guest storage y sesión segura | tests de journey/settings/identity + integración | Verificado en tests |
| SQL como fuente de verdad | `api/db/migrations/0001..0008` y Prisma derivado | `migrations.e2e-spec.ts`, `db:verify` | DB pendiente |
| Fidelidad del prototipo | tokens, assets, rutas y estados catalogados | tests de assets, navegación y semántica | Parcial; golden visual pendiente |
| Accesibilidad/responsive | `Semantics`, targets y `SafeArea` | `test/goldens/prototype_semantics_test.dart` | Verificado en tests |
| Comunidad post-MVP | operaciones OpenAPI marcadas `post-mvp` | contrato + contract test | Explícitamente no runtime |

### RF → módulo → endpoint → migración → prueba

| Grupo RF | Flutter/API | Operaciones | Persistencia | Pruebas |
|---|---|---|---|---|
| RF-001..005 | onboarding, permissions, settings / identity | `/v1/me`, preferences, guest migration | `0002_identity_and_preferences.sql`, `0008_idempotency_operations.sql` | identity, permissions, integration |
| RF-010..014 | search, saved, home / places, favorites | places search/reverse, favorites | `0002`, `0007_indexes_constraints_retention.sql` | places, saved, contract |
| RF-020..024 | nearby, home / transit, provider gateway | nearby stops, departures, routes | `0003_transit_catalog.sql` | transit, provider gateway, semantics |
| RF-030..044 | planner / journeys, alerts | plan/get journey, leave alert | `0004_journeys_and_active_journeys.sql`, `0005_routines_alerts_notifications.sql` | journeys, planner, integration |
| RF-050..056 | journey / active journeys | start/progress/finish/cancel | `0004` | active journeys, journey, integration |
| RF-060..074 | saved, commutes, notifications | favorites, commute profiles, alerts, notifications | `0005`, `0008` | favorites, commutes, notifications, integration |
| RF-080..092 | settings, journey, shared / health, worker, privacy | health, provider status, preferences, export/delete | `0006_reliability_and_community.sql`, `0007`, `0008` | health, worker, identity, contract |

## Fixtures y límites

- `yegamo_app/test/fixtures/prototype_states.dart` sólo se importa desde
  tests. Sus fechas son generadas desde `PrototypeFixtureClock`; el transporte
  registra requests y responde payloads canónicos deterministas.
- La integración configura `demoDataEnabled: false`. Las respuestas de
  planificación son fixtures de prueba `DEGRADED`; descubrimiento responde
  `PROVIDER_UNAVAILABLE`. Ningún fixture declara fuente, timestamp autorizado
  o `LIVE`.
- `DEMO_PROVIDER_ENABLED=true` sólo es válido en desarrollo/pruebas; el
  gateway elimina el adapter en producción.
- Las operaciones `/reports*` continúan publicadas para compatibilidad, pero
  están marcadas `x-implementation-status: post-mvp` y no se contabilizan como
  runtime MVP.

## Comandos y resultados

Los comandos deben ejecutarse desde la raíz salvo que se indique otra ruta. La
tabla incorpora la verificación actualizada del cierre; los resultados de
integración y base de datos se mantienen explícitamente fuera de la categoría
de pase cuando el runner o la precondición externa no completan la ejecución.

| Comando | Resultado | Observación |
|---|---|---|
| `cd yegamo_app && flutter analyze` | PASS — clean | Análisis estático sin hallazgos |
| `cd yegamo_app && flutter test` | PASS — 33 tests | Incluye fixtures, widgets y módulos |
| `cd yegamo_app && flutter test integration_test/full_baseline_flow_test.dart -d R8YY603RZQK` | NOT RUN / incompleta | En el Android físico SM A065M se construyó e instaló, pero el runner reportó `No tests were found`; la prueba no terminó tras ~23 s y el segundo intento terminó con exit 79 |
| Integración/packaging macOS | BLOQUEADA | El empaquetado falló en `rsync` |
| Integración Chrome | NO SOPORTADA | Chrome no es un target soportado para esta integración |
| `cd api && npm run typecheck` | PASS | TypeScript |
| `cd api && npm run build` | PASS | Nest build |
| `cd api && npm test -- --runInBand --watchman=false` | PASS — 12 suites / 44 tests | Jest unit/e2e HTTP |
| `cd api && npm run db:verify` | BLOQUEADA / fallo esperado sin precondición | Llega a `DATABASE_URL is required to verify the schema`; no se maquilla como validación de DB |
| `git diff --check` | PASS | Sin errores de whitespace |

## Precondiciones externas pendientes

1. `DATABASE_URL` y un PostgreSQL real con PostGIS/pgcrypto para ejecutar
   `db:verify` y los escenarios de migración contra una base vacía y una ruta
   de upgrade. El entorno de cierre no proporciona esa base.
2. Un dispositivo/emulador y un runner Flutter configurado para ejecutar la
   integración fuera del modo widget. Si el comando no puede resolver un
   device, se registra `NOT RUN`.
3. Un proveedor autorizado de transporte y geocodificación, con licencia,
   credenciales y configuración separadas por ambiente. Sin él, la semántica
   correcta sigue siendo `UNAVAILABLE`/`PROVIDER_UNAVAILABLE`.
4. Un proceso aprobado de golden images a 393×852 y constraints anchos. Hasta
   entonces sólo se mantienen checks de semántica y layout no frágiles.

## Revisión de seguridad y branding

La revisión final usa `rg` sobre `yegamo_app`, `api` y `context` para examinar
matches de `password`, `secret`, `api_key`, `LIVE`, `providerDisplayName` y
marcas antiguas. Los matches permitidos deben ser documentación de reglas,
campos canónicos nullable/falsos, tests o almacenamiento seguro de tokens; no
se versionan secretos, credenciales, contraseñas ni DTOs propietarios.
El único match con forma de URL de credenciales era el valor local de ejemplo
en `.env.example`; quedó reemplazado por una URL sin usuario ni contraseña.

No se eliminó ningún artefacto del usuario. La eliminación preexistente de
`yeGamo Prototype.html` y los adjuntos permanecen fuera del alcance de este
cierre.

## Ejecución final

La verificación Flutter/API indicada arriba queda registrada con sus
resultados reales. El flujo físico Android no se declara aprobado: el APK se
construyó e instaló, pero el runner no descubrió tests y el segundo intento
terminó con exit 79. La ejecución macOS quedó bloqueada por `rsync` y Chrome
no es un target soportado. La verificación de esquema tampoco se declara
aprobada porque el entorno no tenía `DATABASE_URL`; el comando alcanzó la
guardia explícita que exige esa variable.
