# Especificacion de datos PostgreSQL/PostGIS

## Motor
PostgreSQL con PostGIS. UUID como PK. `timestamptz` para eventos. `geography(Point,4326)` para ubicaciones y `geometry(LineString,4326)` para shapes cuando corresponda.

## Versionado y fuente ejecutable

El SQL de este paquete es una referencia derivada de la version funcional
`1.1.1`. La fuente ejecutable del esquema sera una secuencia de migraciones
deterministas en `api/db/migrations`, aplicables desde cero y desde una version
anterior. Cada migracion debe ser revisable, transaccional cuando el motor lo
permita y compatible con el proceso de rollback documentado. `14_SCHEMA.sql`
se conserva para inspeccion, bootstrap documental y comparacion; no reemplaza
las migraciones.

## Tablas de negocio
- `users`
- `user_preferences`
- `device_installations`
- `data_export_requests`
- `user_preferences`
- `saved_places`
- `commute_profiles`
- `journey_plans`
- `journey_options`
- `journey_legs`
- `active_journeys`
- `journey_events`
- `notifications`
- `leave_alerts`
- `notification_preferences`
- `notification_deliveries`
- `community_reports`
- `report_confirmations`
- `route_observations`
- `route_metrics`
- `provider_health_snapshots`

## Catalogo de transporte
- `transit_agencies`
- `transit_routes`
- `transit_stops`
- `route_stops`
- `provider_references`
- `transit_feed_versions`
- `transit_route_shapes`

## Regla de licencia
`provider_references.storage_policy` define `PERSIST_ALLOWED`, `EPHEMERAL_ONLY` o `METADATA_ONLY`. Jobs de ingesta deben respetarlo.

## Indices
- GiST en `transit_stops.location`, `saved_places.location`, `community_reports.location`.
- B-tree en external IDs, route IDs, timestamps, status.
- Indices compuestos en route metrics por `(route_id, direction, day_of_week, time_bucket)`.

## Retencion
- Location samples detallados: minimizados y retencion corta (ej. 30 dias) solo con consentimiento.
- Metricas agregadas anonimizadas: retencion larga.
- Datos de proveedor: segun licencia/TTL.

## Estado local invitado
Los guardados y preferencias de un invitado pueden vivir exclusivamente en almacenamiento local cifrado/seguro cuando aplique. Al crear cuenta, la migracion a servidor debe ser explicita e idempotente.
