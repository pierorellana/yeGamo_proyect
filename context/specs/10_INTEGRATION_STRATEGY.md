# Estrategia de integraciones

## Principio
La logica de yeGamo consume un contrato canonico y no conoce estructuras de Google, Moovit, GTFS u OSM.

## Interfaces logicas

### TransitPlannerProvider
- `planJourney(origin, destination, departureAt?, arrivalBy?, preferences)`
- `getNearbyStops(point, radius)`
- `getStopDepartures(stopRef, at)`
- `getServiceAlerts(area/route)`

### VehiclePositionProvider
- `getVehiclePositions(routeRef|bbox)`
- Devuelve `LIVE`, `STALE` o `UNAVAILABLE`.

### GeocodingProvider
- `search(query, biasPoint)`
- `reverse(point)`

### TrafficIncidentProvider
- `getIncidents(bbox|corridor)`

## Canonical DTO
Todo proveedor se transforma a: Agency, Route, Stop, JourneyOption, Leg, ETAEstimate, ServiceAlert, VehiclePosition.

## Politica de fallback
1. Primary provider.
2. Secondary provider compatible.
3. Static/cache permitido por licencia con marca de antiguedad.
4. Respuesta "datos no disponibles".

## Timeouts sugeridos
- Geocoding: 2 s.
- Nearby: 2.5 s.
- Plan journey: 5 s por proveedor, con timeout global 7 s.
- Realtime positions: 2 s.

## Circuit breaker
Tras fallos consecutivos, el proveedor se marca `DEGRADED` durante una ventana corta. La UI no necesita saber el detalle tecnico; recibe calidad/frescura.

## Caching
Solo cachear aquello permitido por terminos/licencia. Cache de respuestas externas debe estar etiquetado por proveedor y TTL. Datos GTFS abiertos pueden ingerirse a esquema canonico conforme a licencia; resultados de plataformas con restricciones se tratan como datos efimeros.

## Estrategia de GTFS
Si aparece un feed oficial:
- validar con MobilityData GTFS Validator;
- importar agency/routes/stops/trips/stop_times/shapes/calendar;
- mantener version de feed;
- si existe GTFS-RT, consumir TripUpdates, VehiclePositions, Alerts;
- reconciliar IDs entre static y realtime.
