# Especificacion de API propia - yeGamo

## Convenciones
Base URL `/v1`, JSON, UTC en backend, IDs UUID. Errores: `code`, `message`, `details`, `traceId`.

## Endpoints principales

### Salud / proveedores
- `GET /v1/health`
- `GET /v1/providers/status` (admin)

### Places
- `GET /v1/places/search?q=&lat=&lon=`
- `GET /v1/places/reverse?lat=&lon=`

### Nearby
- `GET /v1/transit/stops/nearby?lat=&lon=&radiusM=`
- `GET /v1/transit/stops/{stopId}/departures`
- `GET /v1/transit/routes/{routeId}`

### Journeys
- `POST /v1/journeys/plan`
- `GET /v1/journeys/{planId}`
- `POST /v1/journeys/{planId}/options/{optionId}/start`
- `GET /v1/active-journeys/{id}`
- `PATCH /v1/active-journeys/{id}/progress`
- `POST /v1/active-journeys/{id}/finish`
- `POST /v1/active-journeys/{id}/cancel`

### Saved places
- `GET /v1/favorites/places`
- `POST /v1/favorites/places`
- `PATCH /v1/favorites/places/{id}`
- `DELETE /v1/favorites/places/{id}`

### Commute profiles
- `GET /v1/commute-profiles`
- `POST /v1/commute-profiles`
- `PATCH /v1/commute-profiles/{id}`
- `DELETE /v1/commute-profiles/{id}`
- `POST /v1/commute-profiles/{id}/pause`
- `POST /v1/commute-profiles/{id}/resume`

### Alerts / notifications
- `POST /v1/alerts/leave`
- `DELETE /v1/alerts/{id}`
- `GET /v1/notifications`
- `PATCH /v1/notifications/{id}/read`
- `POST /v1/notifications/read-all`

### Preferences / privacy
- `GET /v1/me`
- `POST /v1/me/guest-migration`
- `POST /v1/me/devices`
- `DELETE /v1/me/devices/{id}`
- `GET /v1/me/preferences`
- `PATCH /v1/me/preferences`
- `POST /v1/me/data-export`
- `DELETE /v1/me`

Las rutas de identidad, sincronizacion, rutinas, avisos, historial y
privacidad requieren JWT de un proveedor OIDC configurado. La migracion de
invitado requiere `Idempotency-Key`, es explicita, transaccional y auditable.
El registro y la baja de dispositivos son idempotentes respecto a la
instalacion del cliente.

### Community (post-MVP)
- `POST /v1/reports`
- `GET /v1/reports/nearby`
- `POST /v1/reports/{id}/confirm`
- `POST /v1/reports/{id}/resolve`

## Request de planificacion
```json
{
  "origin": {"lat": -2.17, "lon": -79.90},
  "destination": {"lat": -2.14, "lon": -79.89},
  "timeMode": "ARRIVE_BY",
  "time": "2026-10-02T08:00:00-05:00",
  "preference": "RELIABLE",
  "maxWalkMin": 12,
  "extraSafetyMarginMin": 5
}
```

## Respuesta minima
```json
{
  "planId": "uuid",
  "recommendedLeaveAt": "2026-10-02T07:06:00-05:00",
  "arrivalWindow": {"from":"07:48","to":"07:57"},
  "dataState": "CURRENT",
  "options": [{
    "id":"uuid",
    "durationMin":52,
    "walkMin":10,
    "transfers":1,
    "reliability":{"score":84,"level":"HIGH","sampleSize":132},
    "dataQuality":{
      "freshness":"CURRENT",
      "liveVehicle":false,
      "providerDisplayName":null
    },
    "legs":[]
  }]
}
```

`providerDisplayName` solo puede poblarse cuando exista una fuente configurada y autorizada. El prototipo usa nombres de fuentes de demostracion que no deben pasar automaticamente a produccion.

## Estados de datos
- `CURRENT`
- `STALE`
- `DEGRADED`
- `OFFLINE_CACHE`
- `UNAVAILABLE`

## Errores de dominio
- `NO_TRANSIT_OPTIONS`
- `PROVIDER_UNAVAILABLE`
- `PROVIDER_TIMEOUT`
- `LOCATION_OUT_OF_COVERAGE`
- `INSUFFICIENT_DATA`
- `INVALID_TIME_WINDOW`
- `LOCATION_PERMISSION_REQUIRED`
- `OFFLINE_NO_CACHE`
- `RATE_LIMITED`

## Respuesta de calidad y errores

Toda respuesta que incluya datos de movilidad puede declarar `dataState` como
`CURRENT`, `STALE`, `DEGRADED`, `OFFLINE_CACHE` o `UNAVAILABLE`. `LIVE` solo
puede aparecer junto a una fuente autorizada y un timestamp reciente. Cuando
no haya datos confiables, el API devuelve el estado o error correspondiente y
no inventa una ETA.

El error canonico es:

```json
{
  "code": "PROVIDER_TIMEOUT",
  "message": "No fue posible obtener una planificacion actualizada.",
  "details": {},
  "traceId": "uuid-or-trace-value"
}
```
