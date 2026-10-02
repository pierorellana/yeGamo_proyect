# Modelo de dominio

## Entidades principales

### User
Identidad, preferencias, consentimiento, reputacion interna y configuracion de notificaciones.

### Place
Lugar guardado por usuario: coordenada, etiqueta y metadatos de geocodificacion.

### CommuteProfile
Viaje recurrente con origen, destino, dias, hora objetivo, margen y preferencias.

### TransitAgency
Operador/agencia cuando la fuente lo identifica.

### TransitRoute
Representacion canonica de una ruta. Puede tener multiples referencias por proveedor.

### TransitStop
Parada/estacion canonica con geometria y referencias externas.

### ProviderReference
Relaciona entidad canonica con `provider + external_id` y reglas de licencia.

### JourneyPlan
Solicitud de planificacion con origen, destino, modo temporal y preferencias.

### JourneyOption
Alternativa normalizada compuesta por Legs.

### JourneyLeg
Tramo WALK/TRANSIT; contiene tiempos, geometria, parada de origen/destino y detalles de linea.

### JourneyEvent
Evento append-only de una instancia de viaje: cambio de tramo, actualizacion
de ETA, alerta de bajada, pausa, finalizacion o cancelacion, con timestamp,
fuente y calidad normalizadas.

### ActiveJourney
Instancia ejecutada de una opcion con ETA actualizada y estado.

### RouteObservation
Dato observado util para calibracion: duracion, espera, retraso, fuente y calidad.

### RouteMetric
Agregado por ruta, direccion, dia/franja: mediana, percentiles, dispersion y yeGamo Score.

### CommunityReport
Incidencia geolocalizada con tipo, vigencia, evidencia opcional, estado y score de confianza.

### NotificationIntent
Evento de negocio que debe convertirse en push/local notification: salida, bajada, incidente, cambio de ETA.

### UserPreference
Preferencias de planificacion y presentacion del usuario: modo de viaje,
margen de seguridad, caminata maxima, idioma, unidades y consentimiento de
funciones de ubicacion.

### DeviceInstallation
Instalacion de la aplicacion vinculada a una cuenta, con plataforma, token de
notificacion, version de app y estado de activacion. Los tokens son revocables
y nunca se exponen como secretos de negocio.

### NotificationDelivery
Intento de entrega de una notificacion a una instalacion, con canal, estado,
timestamps, proveedor y clave de deduplicacion.

### DataExportRequest
Solicitud auditable de exportacion de los datos del usuario, con estado,
expiracion, formato y referencia segura al resultado.

### ProviderHealthSnapshot
Snapshot de salud de un adapter: proveedor, endpoint/capacidad, estado,
latencia, errores, frescura y timestamp. No autoriza por si solo la etiqueta
`LIVE`; esa decision exige fuente autorizada y timestamp de dato valido.

## Value Objects
- GeoPoint
- TimeWindow
- ETAEstimate `{min, expected, max, confidence}`
- TravelPreference
- ProviderFreshness
- ReliabilityScore

## Estados de ActiveJourney
`PLANNED -> ACTIVE -> COMPLETED | CANCELLED | ABANDONED`.

## Estados de CommunityReport
`ACTIVE -> CONFIRMED -> RESOLVED | EXPIRED | REJECTED`.
