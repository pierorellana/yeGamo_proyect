# Especificacion de backend Node.js

## Stack
- Node.js + TypeScript.
- NestJS como framework de referencia.
- PostgreSQL + PostGIS.
- ORM/query layer compatible con geospatial; SQL explicito para consultas criticas PostGIS.
- OpenAPI generado/validado contra `12_OPENAPI.yaml`.

## Modulos
- Auth.
- Users/Preferences.
- Places.
- Transit Catalog.
- Journey Planning.
- ETA/Reliability.
- Active Journey.
- Commute Profiles.
- Leave Alerts.
- Notifications Center.
- Preferences/Privacy.
- Community Reports.
- Provider Gateway.
- Admin/Observability.

## Provider Gateway
Cada proveedor implementa interfaces y mappers. El gateway decide prioridad, timeout, cache, circuit breaker y fallback. Credenciales viven en backend.

## Jobs
- Descubrimiento/refresh GTFS cuando aplique.
- Calculo de route metrics.
- Expiracion de reportes.
- Evaluacion de commute profiles para alertas.
- Limpieza/retencion.

## Tiempo real
No es requisito del MVP. Para fases Live, usar WebSocket/SSE desde nuestra API solo para eventos que realmente cambian; no retransmitir polling innecesario.

## Idempotencia
Endpoints que crean reportes, inician viajes o programan alertas deben soportar idempotency key cuando la repeticion movil pueda duplicar operaciones.

## Contrato de calidad de datos
Cada respuesta de planificacion debe exponer un `dataState` normalizado y metadatos de frescura. El backend, no la UI, decide si una fuente puede llamarse LIVE o mostrarse por nombre.
