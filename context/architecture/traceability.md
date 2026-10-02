# Trazabilidad transversal de yeGamo

## Propósito

Esta matriz conecta los grupos de requisitos funcionales con el contrato HTTP,
el modelo persistente, la superficie Flutter y las pruebas de aceptación. Es
un índice de implementación, no una sustitución de las specs: los detalles de
comportamiento están en `context/specs/`, el contrato canónico en
`api/contracts/openapi.yaml` y el esquema ejecutable futuro en
`api/db/migrations/`.

## Reglas de interpretación

- El sistema es un monolito modular; los nombres de módulos de esta matriz son
  límites de capacidad, no microservicios.
- Los endpoints son REST/JSON versionados bajo `/v1`. Las rutas de lugares y
  planificación pueden ser públicas; sincronización, rutinas, avisos,
  historial y privacidad requieren identidad configurada.
- Los nombres de tablas son nombres del modelo PostgreSQL/PostGIS canónico.
  Los datos de ubicación precisos no se conservan por defecto y las políticas
  de licencia de proveedores se respetan.
- `LIVE` requiere fuente autorizada y timestamp reciente. El API decide
  `CURRENT`, `STALE`, `DEGRADED`, `OFFLINE_CACHE` o `UNAVAILABLE`; Flutter no
  inventa ETA ni expone DTOs de proveedores.
- Las pruebas nombradas son suites o escenarios mínimos que deben convertirse
  en pruebas automatizadas dentro de los planes de API y Flutter.

## Matriz RF → integración → pruebas

| Grupo de requisitos | Endpoints OpenAPI relacionados | Tablas principales | Módulos Flutter | Pruebas de aceptación mínimas |
|---|---|---|---|---|
| `RF-001..RF-005` | `GET /v1/me`, `POST /v1/me/guest-migration`, `GET /v1/me/preferences`, `PATCH /v1/me/preferences` | `users`, `user_preferences`, `device_installations`, `data_export_requests` | `modules/onboarding`, `modules/permissions`, `modules/settings`, `shared/session`, `shared/storage`, `shared/security` | Widget de onboarding de 3 pasos; permiso aceptado/denegado; E2E primer inicio → onboarding → permiso → inicio; migración guest→cuenta idempotente con `Idempotency-Key`; no se almacenan contraseñas. |
| `RF-010..RF-014` | `GET /v1/places/search`, `GET /v1/places/reverse`, `GET /v1/favorites/places`, `POST /v1/favorites/places`, `PATCH /v1/favorites/places/{id}`, `DELETE /v1/favorites/places/{id}` | `saved_places`, `provider_references`; ubicación precisa solo local/efímera según consentimiento | `modules/permissions`, `modules/search`, `modules/saved`, `modules/home`, `shared/location`, `shared/storage` | Widget permiso aceptado/denegado y origen manual; contract tests de búsqueda/reverse; guardado invitado persiste al reiniciar; selección de mapa y recientes; error/offline recuperable. |
| `RF-020..RF-024` | `GET /v1/transit/stops/nearby`, `GET /v1/transit/stops/{stopId}/departures`, `GET /v1/transit/routes/{routeId}` | `transit_agencies`, `transit_routes`, `transit_stops`, `route_stops`, `provider_references`, `transit_feed_versions` | `modules/nearby`, `modules/home`, `shared/location`, `shared/widgets`, `shared/design_system` | Contract fixtures de paradas/salidas con campos ausentes y stale; radio configurable; widget `LIVE` vs `ESTIMATED` por texto y forma; no coverage; proveedor no disponible sin ETA inventada. |
| `RF-030..RF-044` | `POST /v1/journeys/plan`, `GET /v1/journeys/{planId}`, `POST /v1/alerts/leave`, `DELETE /v1/alerts/{id}` | `journey_plans`, `journey_options`, `journey_legs`, `journey_events`, `leave_alerts`, `route_observations`, `route_metrics`, `provider_references` | `modules/search`, `modules/planner`, `modules/journey`, `shared/models`, `shared/services`, `shared/routes` | Unitarias de duración/ranking/margen/hora de salida; widget `Salir ahora` y `Llegar a las`; alternativas `ok/empty/error/nocoverage`; desglose de tiempo; alerta creada una sola vez; timeout sin fallback no muestra ETA. |
| `RF-050..RF-056` | `POST /v1/journeys/{planId}/options/{optionId}/start`, `GET /v1/active-journeys/{id}`, `PATCH /v1/active-journeys/{id}/progress`, `POST /v1/active-journeys/{id}/finish`, `POST /v1/active-journeys/{id}/cancel` | `active_journeys`, `journey_events`, `journey_options`, `route_observations`, `route_metrics` | `modules/journey`, `shared/location`, `shared/notifications`, `shared/services` | E2E alternativa → viaje activo → alerta → finalizar; progreso y próximas paradas; desvío con sugerencia de recálculo; finish/cancel idempotente; ventana prevista y degradación visibles. |
| `RF-060..RF-074` | `GET/POST/PATCH/DELETE /v1/favorites/places`, `GET/POST/PATCH/DELETE /v1/commute-profiles`, `POST /v1/commute-profiles/{id}/pause`, `POST /v1/commute-profiles/{id}/resume`, `POST /v1/alerts/leave`, `GET /v1/notifications`, `PATCH /v1/notifications/{id}/read`, `POST /v1/notifications/read-all` | `saved_places`, `journey_plans`, `commute_profiles`, `leave_alerts`, `notifications`, `notification_preferences`, `notification_deliveries`, `users` | `modules/saved`, `modules/commutes`, `modules/notifications`, `modules/planner`, `shared/notifications`, `shared/storage`, `shared/session` | Widget guardados invitado; rutina activa/pausada/sugerida; crear/editar/eliminar rutina; centro de avisos y marcar leídos; una sola notificación por `notificationId`/`Idempotency-Key`; E2E rutina → alerta → entrega. |
| `RF-080..RF-092` | `GET /v1/providers/status`, `GET /v1/health`, `GET /v1/journeys/{planId}`, `GET /v1/me/preferences`, `PATCH /v1/me/preferences`, `POST /v1/me/data-export`, `DELETE /v1/me`, `POST /v1/reports`, `GET /v1/reports/nearby` (community post-MVP) | `journey_plans`, `journey_options`, `journey_legs`, `journey_events`, `route_observations`, `route_metrics`, `provider_health_snapshots`, `data_export_requests`, `users`, `community_reports`, `report_confirmations` | `modules/planner`, `modules/journey`, `modules/settings`, `modules/notifications`, `shared/design_system`, `shared/analytics`, `shared/security` | Unitarias de fiabilidad, muestra mínima y cambio material; contract fixtures `CURRENT/STALE/DEGRADED/UNAVAILABLE`; provider fallback/timeout; exportación y eliminación; migraciones/retención; health y porcentaje degradado; ningún `LIVE` sin fuente/timestamp. |

## Cobertura de pantallas y estados

La matriz de pantallas está en
[`../prototype/screens/yeGamo-mobile.md`](../prototype/screens/yeGamo-mobile.md).
Sus 17 filas cubren `Splash`, `Onboarding`, `Permisos`, `Inicio`, `Buscar`,
`Cercano`, `Planificador`, `Cargando`, `Alternativas`, `Cuándo salir` (la
spec funcional lo describe también como `Hora de salida`), `Paso a paso`,
`Viaje activo`, `Alerta de bajada`, `Guardados`, `Rutinas`, `Avisos` y
`Ajustes`.

Los nueve estados UX baseline son `ok`, `loading`, `empty`, `error`,
`offline`, `stale`, `degraded`, `permission` y `nocoverage`. Deben conservar
la semántica de datos del API: `offline` solo puede mostrar cache etiquetada
como `OFFLINE_CACHE` o `STALE`, y `degraded` debe indicar qué parte de la
respuesta es parcial.

## Límite del prototipo

`yeGamo Prototype.html` es referencia visual y de flujo. Sus nombres de
fuentes, horarios, lugares, scores, muestras y disponibilidad son datos demo;
no son fuente productiva. La integración real depende del contrato del API,
las migraciones, la configuración de proveedores autorizados y sus licencias.
