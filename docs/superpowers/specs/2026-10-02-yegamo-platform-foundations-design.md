# yeGamo Platform Foundations Design

**Fecha:** 2026-10-02  
**Estado:** aprobado por el usuario  
**Fuente funcional:** `yeGamo_Documentacion_Oficial_v1.1.pdf` y `yeGamo_Specs_v1.1.zip`  
**Referencia visual y de flujo:** `yeGamo Prototype.html`  

## Objetivo

Establecer las fundaciones escalables de yeGamo: un workspace SDD común, una
aplicación Flutter modular, un API NestJS modular y una base PostgreSQL/PostGIS
con migraciones SQL versionadas. El diseño cubre el MVP Core de Guayaquil y
permite ampliar ciudades, proveedores y capacidades sin acoplar el dominio a
un proveedor externo.

Este documento formaliza decisiones aprobadas antes de escribir código. La
implementación se dividirá en tres subproyectos: fundaciones y contrato, API y
base de datos, y aplicación Flutter.

## Principios e invariantes

- La decisión principal de producto es la hora recomendada de salida.
- Las llegadas son estimaciones; se muestran rangos cuando la incertidumbre lo
  exige.
- `LIVE` solo existe con fuente autorizada y timestamp reciente.
- Una posición inferida se presenta como `ESTIMATED`, nunca como `LIVE`.
- Los nombres de fuente, frescura y calidad los decide el backend.
- Los horarios, scores, lugares y fuentes del prototipo son datos demo.
- Ningún proveedor externo filtra sus DTOs hacia Flutter o el dominio.
- Los invitados pueden planificar y guardar localmente sin crear una cuenta.
- La sincronización invitado→cuenta es explícita, idempotente y auditable.
- La ubicación precisa no se conserva por defecto.
- Las reglas de negocio viven en el API, no en widgets ni middleware HTTP.
- El sistema funciona como monolito modular; no se crean microservicios para el
  MVP.
- El trabajo se documenta como `spec → diseño/ADR → plan → implementación →
  pruebas → revisión → cierre`.

## Alcance

### Incluido

- Las 17 pantallas del prototipo: Splash, Onboarding, Permisos, Inicio,
  Buscar, Cercano, Planificador, Cargando, Alternativas, Cuándo salir, Paso a
  paso, Viaje activo, Alerta de bajada, Guardados, Rutinas, Avisos y Ajustes.
- Los 9 estados UX: `ok`, `loading`, `empty`, `error`, `offline`, `stale`,
  `degraded`, `permission` y `nocoverage`.
- Planificación `Salir ahora` y `Llegar a las`.
- Alternativas, hora recomendada, explicabilidad, paso a paso y viaje activo.
- Guardados, rutinas, avisos, privacidad y cuenta opcional.
- Proveedor demo aislado para desarrollo y pruebas.
- Gateway de proveedores preparado para un adapter productivo como Google
  Transit, sujeto a cobertura, licencia y configuración.
- PostgreSQL + PostGIS, persistencia local de invitado y migración idempotente.

### Fuera del MVP

- GPS propio instalado en buses.
- Posiciones de vehículos en tiempo real sin fuente autorizada.
- Comunidad y ocupación como requisito de lanzamiento.
- Microservicios independientes.
- Elección de un proveedor OIDC concreto dentro del dominio.

## Topología del workspace

El proyecto se gestionará como un único workspace y un único repositorio raíz.
La estructura objetivo es:

```text
yeGamo/
├── AGENTS.md
├── context/
│   ├── README.md
│   ├── specs/
│   ├── adr/
│   ├── architecture/
│   ├── plans/
│   └── prototype/
├── yegamo_app/
├── api/
│   ├── src/
│   ├── contracts/
│   ├── db/
│   │   ├── migrations/
│   │   └── seeds/
│   └── test/
├── docs/superpowers/
└── docker-compose.yml
```

`yegamo_app/` es el proyecto Flutter existente y se conserva como nombre de
superficie durante la primera fase. `api/` será la superficie NestJS. `context/`
será la documentación canónica de comportamiento, decisiones y trazabilidad.

## Arquitectura general

```text
Flutter
  │ REST/JSON /v1
  ▼
NestJS API modular
  ├── identidad, usuarios y preferencias
  ├── lugares y catálogo de transporte
  ├── planificación y confiabilidad
  ├── viaje activo
  ├── rutinas, alertas y avisos
  ├── privacidad
  ├── gateway de proveedores
  └── jobs y observabilidad
       │
       ├── PostgreSQL + PostGIS
       └── proveedores externos autorizados
```

El API será stateless en las peticiones HTTP. El estado duradero se guarda en
PostgreSQL; el estado temporal de jobs, circuit breakers y cache se abstrae para
poder moverlo a infraestructura administrada cuando el volumen lo requiera.

## Arquitectura del API

### Estructura de módulos

```text
api/src/
├── main.ts
├── app.module.ts
├── config/
├── shared/
│   ├── errors/
│   ├── observability/
│   ├── auth/
│   ├── database/
│   └── idempotency/
├── modules/
│   ├── auth/
│   ├── users/
│   ├── preferences/
│   ├── places/
│   ├── transit/
│   ├── journey-planning/
│   ├── active-journeys/
│   ├── commute-profiles/
│   ├── leave-alerts/
│   ├── notifications/
│   ├── privacy/
│   ├── reliability/
│   └── community/
├── provider-gateway/
│   ├── domain/
│   ├── application/
│   ├── adapters/
│   └── mappers/
├── jobs/
└── composition/
```

Cada módulo puede contener `domain`, `application`, `infrastructure` y
`presentation`. El núcleo de planificación, ranking, confiabilidad y gateway no
importa NestJS, Prisma, `pg` ni proveedores. Los módulos CRUD pueden utilizar una
separación por capas más directa sin romper el límite del dominio.

### Pipeline HTTP

```text
request
→ contexto de trace
→ autenticación/autorización
→ validación OpenAPI
→ controller
→ caso de uso
→ regla de dominio
→ repositorio o provider gateway
→ mapper canónico
→ respuesta /v1
```

El API utilizará NestJS con módulos, inyección de dependencias, pipes globales
de validación, guards de autenticación/autorización, interceptores para trace y
filtros globales de excepciones. Las respuestas de error tendrán esta forma:

```json
{
  "code": "PROVIDER_TIMEOUT",
  "message": "No fue posible obtener una planificación actualizada.",
  "details": {},
  "traceId": "uuid-or-trace-value"
}
```

### Identidad

- Las rutas públicas permiten búsqueda, cercanía y planificación anónima.
- Las rutas de sincronización, rutinas, historial, avisos y privacidad exigen
  JWT emitido por un proveedor OIDC configurado por ambiente.
- El backend valida el JWT y vincula el `subject` externo con `users`.
- El backend no almacena contraseñas.
- La migración de datos invitados se ejecuta una vez por `Idempotency-Key` y
  deja evidencia de resultado.

### Provider Gateway

El dominio solo depende de interfaces canónicas:

```text
TransitPlannerProvider
GeocodingProvider
VehiclePositionProvider
TrafficIncidentProvider
```

El gateway decide proveedor primario, proveedor secundario, timeout, circuit
breaker, cache permitido por licencia, frescura, `dataState` y mapeo a modelos
canónicos. `DemoTransitProvider` existe solo en desarrollo, pruebas y ambientes
de demostración marcados. Producción sin proveedor autorizado devuelve
`UNAVAILABLE` o `DEGRADED` y nunca inventa resultados.

### Jobs y tiempo real

Los jobs se ejecutan en un proceso worker separado que comparte el código del
API:

- Evaluar rutinas y alertas de salida.
- Emitir notificaciones y registrar entregas.
- Expirar reportes.
- Limpiar datos conforme a retención.
- Calcular métricas agregadas de rutas.
- Refrescar feeds GTFS cuando la licencia lo permita.

El MVP no requiere WebSocket/SSE. Se agregará streaming solo cuando un evento
de movilidad justifique el costo operativo.

## Contrato API

El contrato canónico será `api/contracts/openapi.yaml`, versionado bajo `/v1`.
Debe cubrir todos los endpoints funcionales, no solo los cuatro del YAML actual.
Incluirá esquemas para lugares, paradas, rutas, legs, opciones, calidad,
confiabilidad, viajes activos, rutinas, alertas, avisos, preferencias, errores,
dispositivos y privacidad.

Las operaciones principales serán:

```text
GET    /v1/health
GET    /v1/providers/status
GET    /v1/places/search
GET    /v1/places/reverse
GET    /v1/transit/stops/nearby
GET    /v1/transit/stops/{stopId}/departures
GET    /v1/transit/routes/{routeId}
POST   /v1/journeys/plan
GET    /v1/journeys/{planId}
POST   /v1/journeys/{planId}/options/{optionId}/start
GET    /v1/active-journeys/{id}
PATCH  /v1/active-journeys/{id}/progress
POST   /v1/active-journeys/{id}/finish
POST   /v1/active-journeys/{id}/cancel
GET    /v1/favorites/places
POST   /v1/favorites/places
PATCH  /v1/favorites/places/{id}
DELETE /v1/favorites/places/{id}
GET    /v1/commute-profiles
POST   /v1/commute-profiles
PATCH  /v1/commute-profiles/{id}
DELETE /v1/commute-profiles/{id}
POST   /v1/alerts/leave
DELETE /v1/alerts/{id}
GET    /v1/notifications
PATCH  /v1/notifications/{id}/read
POST   /v1/notifications/read-all
GET    /v1/me/preferences
PATCH  /v1/me/preferences
POST   /v1/me/data-export
DELETE /v1/me
POST   /v1/me/guest-migration
POST   /v1/me/devices
DELETE /v1/me/devices/{id}
```

`Idempotency-Key` será obligatorio para crear alertas, iniciar viajes, migrar
datos y registrar dispositivos cuando un reintento pueda duplicar el efecto.

## Arquitectura Flutter

La app seguirá el patrón modular de `/Users/jorge/Desktop/context/app`, usando
`env`, `modules` y `shared`.

```text
yegamo_app/lib/
├── env/
│   ├── config/
│   ├── environment.dart
│   └── theme/
├── modules/
│   ├── onboarding/
│   ├── permissions/
│   ├── home/
│   ├── search/
│   ├── nearby/
│   ├── planner/
│   ├── journey/
│   ├── saved/
│   ├── commutes/
│   ├── notifications/
│   └── settings/
└── shared/
    ├── models/
    ├── services/
    ├── security/
    ├── session/
    ├── localization/
    ├── notifications/
    ├── storage/
    ├── location/
    ├── routes/
    ├── navigation/
    ├── widgets/
    ├── design_system/
    └── analytics/
```

Cada módulo usa `pages`, `widgets`, `models`, `providers` y `services`.

Decisiones:

- `provider` + `ChangeNotifier` para estado.
- `MultiProvider` como raíz de inyección.
- `MaterialApp`, rutas nombradas y `Navigator`.
- `IndexedStack` para conservar el estado de las secciones principales.
- Un cliente HTTP compartido en `shared/services`.
- Servicios sin `BuildContext`.
- Providers para carga, vacío, error, mapeo y bloqueo de doble envío.
- Nuevas capacidades reutilizables se consolidan en `shared`; no se agregan
  imports directos nuevos entre módulos.

La pantalla `Cargando` se conserva como superficie explícita para mantener la
trazabilidad del prototipo, aunque la operación pueda reutilizar el controller
de planificación.

La persistencia local separa secretos, preferencias estructuradas y cache. Los
tokens viven en almacenamiento seguro. Favoritos, Casa/Trabajo, recientes y
planes permitidos por licencia viven en un almacenamiento local estructurado.
Todo plan local se marca `OFFLINE_CACHE` o `STALE` y nunca se usa como ETA
actual sin indicarlo.

## PostgreSQL/PostGIS

La base de datos es SQL-first. Las migraciones viven en:

```text
api/db/
├── migrations/
│   ├── 0001_extensions.sql
│   ├── 0002_identity_preferences.sql
│   ├── 0003_transit_catalog.sql
│   ├── 0004_journey_planning.sql
│   ├── 0005_active_journeys.sql
│   ├── 0006_commutes_alerts_notifications.sql
│   ├── 0007_reliability_metrics.sql
│   ├── 0008_privacy_operations.sql
│   └── 0009_community_post_mvp.sql
└── seeds/development.sql
```

El runner de migraciones será determinista y ejecutará SQL versionado. Prisma
Client será el acceso tipado por defecto para CRUD y repositorios. `pg` crudo
se reservará para consultas PostGIS, locking o concurrencia que Prisma no pueda
expresar; cada uso tendrá una justificación local.

### Entidades

Identidad y preferencias:

```text
users
user_preferences
notification_preferences
device_installations
data_export_requests
```

Catálogo:

```text
transit_agencies
transit_routes
transit_stops
route_stops
provider_references
transit_feed_versions
transit_route_shapes
```

Planificación y viajes:

```text
journey_plans
journey_options
journey_legs
active_journeys
journey_events
```

Rutinas y avisos:

```text
saved_places
commute_profiles
leave_alerts
notifications
notification_deliveries
```

Confiabilidad y post-MVP:

```text
route_observations
route_metrics
provider_health_snapshots
community_reports
report_confirmations
```

Las ubicaciones se almacenan como `geography(Point,4326)` y los shapes como
`geometry(LineString,4326)`. Se crearán índices GiST espaciales y B-tree para
referencias externas, estado y timestamps. Los estados, preferencias y
políticas de almacenamiento tendrán `CHECK` constraints y las claves foráneas
tendrán `ON DELETE` explícito.

Las observaciones detalladas de ubicación tendrán retención corta y requerirán
consentimiento. Las métricas agregadas podrán retenerse más tiempo sin
coordenadas precisas innecesarias.

## Calidad, errores y observabilidad

El API normaliza calidad de datos a:

```text
CURRENT
STALE
DEGRADED
OFFLINE_CACHE
UNAVAILABLE
```

La UI los representa como los nueve estados del prototipo. Un timeout usa
fallback; sin fallback devuelve error recuperable. Un cambio de recomendación
mayor a cinco minutos conserva una causa disponible. Alertas y operaciones
repetibles se protegen en API, worker y base de datos.

Cada request registra `traceId`, endpoint, resultado, latencia, proveedor,
fallback, estado de datos y código de error sin tokens ni coordenadas precisas
innecesarias.

## Pruebas y aceptación

### API y base

- Unitarias de cálculo de salida, ranking, margen y confiabilidad.
- Tests de adapters y mappers de proveedores.
- Contract tests contra OpenAPI.
- Integración con PostgreSQL/PostGIS real.
- Aplicación de migraciones desde base vacía y desde versiones anteriores.
- Idempotencia y concurrencia de alertas, viajes y migración de invitado.
- E2E de planificación, viaje, privacidad y fallback.

### Flutter

- Tests de modelos, mappers y servicios.
- Widget tests de las 17 pantallas.
- Tests de los 9 estados UX.
- Persistencia de invitado y reinicio de la aplicación.
- Expiración de sesión.
- Reintento, cancelación y cache offline.
- Integration tests de los flujos principales.

### Criterios de salida

- Las 17 pantallas tienen trazabilidad y representación implementable.
- Los 9 estados tienen representación y recuperación coherentes.
- El API valida el contrato OpenAPI completo.
- Las migraciones son reproducibles.
- Ningún dato demo aparece como productivo.
- Ningún vehículo aparece `LIVE` sin fuente autorizada y timestamp reciente.
- Las alertas no se duplican.
- Exportación y eliminación de datos están probadas.
- Los favoritos de invitado sobreviven al reinicio.
- No se agregan dependencias nuevas entre módulos Flutter sin consolidación en
  `shared`.

## Alineación de specs

Se actualizarán los documentos v1.1 para eliminar contradicciones y completar
la trazabilidad:

| Documento | Cambio requerido |
|---|---|
| `00_README.md` | Sustituir Riverpod por el patrón Flutter modular aprobado |
| `07_DOMAIN_MODEL.md` | Añadir legs, eventos, preferencias, dispositivos, entregas y privacidad |
| `11_API_SPEC.md` | Completar endpoints, paginación, auth OIDC, guest migration, dispositivos e idempotencia |
| `12_OPENAPI.yaml` | Convertirlo en contrato completo y validable |
| `13_DATABASE_SPEC.md` | Alinear tablas, retención, licencias y datos operativos |
| `14_SCHEMA.sql` | Reemplazar por migraciones SQL completas y versionadas |
| `15_MOBILE_FLUTTER_SPEC.md` | Documentar `env/modules/shared`, Provider, rutas nombradas, Navigator e IndexedStack |
| `16_BACKEND_NODE_SPEC.md` | Detallar módulos NestJS, persistencia, jobs y gateway |
| `19_TESTING_ACCEPTANCE.md` | Añadir migraciones, guest migration, contrato completo y estados offline |
| `21_ADR.md` | Añadir workspace, Flutter modular, OIDC y migraciones SQL |
| `24_PROTOTYPE_TRACEABILITY.md` | Mantener 17 pantallas y 9 estados como baseline oficial |
| `25_DESIGN_SYSTEM.md` | Mapear tokens a componentes Flutter |

El prototipo conserva su función de referencia visual, pero se registran como
deuda de limpieza sus textos heredados `RutaYa`, nombres de fuente demo,
conteos antiguos y cifras simuladas.

## Secuencia de subproyectos

1. **Fundaciones:** crear contexto general, ADRs, arquitectura, contrato
   OpenAPI completo y reglas de validación.
2. **API y base:** crear NestJS, módulos, migraciones, repositorios, gateway,
   jobs y pruebas.
3. **Flutter:** adaptar el scaffold a `env/modules/shared`, implementar cliente
   HTTP, persistencia, providers, navegación, design system y las 17 pantallas.

Cada subproyecto tendrá su propia spec, plan de implementación, pruebas y
revisión antes de avanzar al siguiente.
