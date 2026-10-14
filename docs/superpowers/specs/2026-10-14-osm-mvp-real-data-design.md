# yeGamo — datos geográficos reales para el MVP

**Fecha:** 2026-10-14
**Estado:** Diseño aprobado para planificación
**Alcance:** primera fase sin costo de búsqueda de lugares y paradas cercanas

## Objetivo

Hacer que el MVP muestre información geográfica real y verificable sin usar
datos simulados ni exigir una cuenta de facturación externa. La primera fase
debe resolver búsqueda de lugares y visualización de paradas cercanas. Las
horas de salida, ETA, posiciones de buses y alertas en tiempo real quedan
fuera de alcance.

## Decisiones

1. El mapa seguirá renderizándose con MapLibre y una fuente basada en
   OpenStreetMap, con atribución visible y URL de tiles configurable.
2. Flutter no consumirá directamente Nominatim ni Overpass. El API actuará
   como gateway para controlar caché, límites, errores y normalización.
3. Nominatim continuará siendo el proveedor de geocodificación para
   `/v1/places/search`.
4. Overpass será el proveedor de descubrimiento inicial de paradas OSM. Las
   paradas descubiertas se persistirán en `transit_stops` y se identificarán
   mediante `provider_references` con `provider = openstreetmap`.
5. `/v1/transit/stops/nearby` leerá primero PostgreSQL/PostGIS. Solo cuando no
   existan resultados locales en el radio solicitado intentará descubrir
   paradas OSM, persistirlas y repetir la lectura local.
6. Las paradas OSM se devolverán con `dataState = DEGRADED`: la ubicación es
   real, pero no representa horarios, ETA ni una fuente autorizada de tiempo
   real.
7. El contrato de `TransitStop` incorporará `source`, nullable, con el valor
   público `openstreetmap` cuando la relación de proveedor esté disponible.
8. No se habilitará ninguna ruta de planificación ni dato de llegada a partir
   de esta integración.

## Flujo de datos

```text
Flutter
  ├─ /v1/places/search ────────────────┐
  └─ /v1/transit/stops/nearby ─────────┤
                                       ▼
                              API yeGamo
                         ┌───────────────┐
                         │ PostgreSQL     │
                         │ PostGIS        │
                         └───────┬───────┘
                                 │ sin resultados
                                 ▼
                         Overpass / OSM
                                 │
                                 ▼
                    upsert + provider_references
                                 │
                                 ▼
                         lectura local final
```

### Geocodificación

El backend mantiene el adaptador Nominatim existente. Las consultas deben
usar búsqueda libre, `format=jsonv2`, idioma español, límite pequeño,
`countrycodes=ec` y un `viewbox` alrededor de la posición cuando exista.

El adaptador debe conservar caché por consulta normalizada y posición
aproximada, respetar como mínimo un intervalo de un segundo entre peticiones
externas y enviar un `User-Agent` identificable. Flutter aplicará debounce de
500 ms y no buscará con menos de tres caracteres.

### Descubrimiento de paradas

El adaptador Overpass consultará una caja geográfica acotada alrededor de la
posición. La consulta incluirá, como mínimo, nodos con:

- `highway=bus_stop`;
- `public_transport=platform`;
- `public_transport=stop_position`.

La respuesta se validará antes de persistirse. Cada candidato requiere:

```text
externalId: node:<osm-id>
name: nombre etiquetado o "Parada sin nombre"
lat/lon: coordenadas válidas
provider: openstreetmap
```

El proveedor tendrá un caché por celda geográfica con TTL configurable de
quince minutos para evitar repetir consultas públicas. El endpoint de
Overpass será configurable y el adaptador tendrá timeout explícito. Si el
proveedor falla, se conserva la lectura local y se devuelve un estado vacío o
limitado; no se inventan paradas.

### Persistencia idempotente

La escritura se ejecutará dentro de una transacción:

1. Buscar `provider_references` por
   `(provider, entity_type, external_id)`.
2. Si existe, actualizar nombre, coordenadas y `last_seen_at` de la parada.
3. Si no existe, crear `transit_stops` y su referencia de proveedor.
4. No crear agencias, rutas, horarios ni relaciones `route_stops` a partir de
   una parada aislada de OSM.

La consulta local devolverá la fuente pública a partir de la referencia de
proveedor. Los DTOs de Overpass no cruzarán el gateway HTTP.

## Contrato HTTP

Se mantienen las rutas existentes:

- `GET /v1/places/search`
- `GET /v1/transit/stops/nearby`

El esquema `TransitStop` agrega:

```yaml
source:
  type: string
  nullable: true
  example: openstreetmap
```

No se agrega un endpoint público de sincronización. El descubrimiento es una
decisión interna del API al resolver una consulta de cercanía.

## Experiencia Flutter

### Inicio y mapa

- La ubicación se solicita mediante el permiso nativo del sistema.
- Con ubicación disponible, se consulta el endpoint de paradas cercanas.
- Los marcadores se dibujan desde las paradas y resultados de búsqueda reales.
- La tarjeta de Inicio muestra carga, resultados, vacío, offline y error de
  proveedor con mensajes distintos.
- Una parada muestra nombre, distancia, fuente "OpenStreetMap" y el estado
  "Datos limitados".
- No se muestra `LIVE`, ETA, horario ni una próxima salida sin feed
  autorizado.

### Búsqueda

- La búsqueda comienza después de 500 ms sin cambios.
- Se ignoran textos de menos de tres caracteres.
- La lista muestra nombre, ubicación y fuente.
- Seleccionar un resultado centra el mapa en sus coordenadas.
- Un resultado vacío muestra un estado explícito y mantiene el mapa usable.

La atribución de OpenStreetMap debe permanecer visible en la superficie del
mapa. El proveedor de tiles debe poder cambiarse por configuración sin
modificar el cliente.

## Configuración

Variables previstas:

```text
OVERPASS_ENABLED=true
OVERPASS_BASE_URL=https://overpass-api.de/api/interpreter
OVERPASS_TIMEOUT_MS=10000
OVERPASS_CACHE_TTL_MS=900000
NOMINATIM_ENABLED=true
NOMINATIM_USER_AGENT=yeGamo/<version> (<contacto>)
```

En producción, `OVERPASS_ENABLED` debe requerir habilitación explícita. No
se versionan secretos ni credenciales; esta integración no requiere API key.

## Estados y errores

- Sin permiso de ubicación: estado de permiso nativo.
- Sin conexión: estado offline sin consulta externa.
- Sin paradas locales y Overpass sin resultados: estado vacío con mensaje de
  cobertura limitada.
- Overpass/Nominatim caído o limitado: estado degradado/error retryable sin
  inventar datos.
- Datos locales disponibles aunque el proveedor externo falle: se devuelven
  los datos locales y se conserva `DEGRADED`.

## Pruebas de aceptación

1. Una búsqueda de tres o más caracteres no genera más de una llamada externa
   después del debounce.
2. La búsqueda devuelve lugares reales normalizados sin campos propios de
   Nominatim.
3. Una consulta de paradas con datos locales no llama a Overpass.
4. Una consulta sin datos locales llama a Overpass una sola vez por celda y
   TTL, persiste las paradas y las devuelve en la misma respuesta.
5. Repetir la misma respuesta OSM no crea filas duplicadas.
6. Una respuesta inválida o timeout de Overpass no rompe el endpoint ni
   produce paradas sintéticas.
7. Flutter muestra marcadores de paradas y lugares, fuente visible y estado
   limitado.
8. Flutter muestra estados diferenciados para carga, vacío, offline y error.
9. Ninguna prueba ni fixture de producción introduce ETA, horarios, rutas o
   posiciones de buses inventadas.

## Fuera de alcance

- GTFS o GTFS-Realtime del ATM.
- Posición de vehículos, alertas y ETA.
- Google Routes Transit.
- Planificación de viajes de transporte público.
- Motor de rutas peatonales o automotor.
- Descargas offline o precarga masiva de tiles.
- Cuenta de usuario, favoritos o persistencia de ubicación precisa nueva.

## Referencias

- [Política de tiles de OpenStreetMap](https://operations.osmfoundation.org/policies/tiles/)
- [Política de Nominatim](https://operations.osmfoundation.org/policies/nominatim/)
- [Documentación de búsqueda Nominatim](https://nominatim.org/release-docs/latest/api/Search)
- [Documentación de Overpass](https://wiki.openstreetmap.org/wiki/Overpass_API)
- [Contrato HTTP canónico](../../../api/contracts/openapi.yaml)
- [Investigación de fuentes externas](../../../context/specs/09_EXTERNAL_DATA_RESEARCH.md)
