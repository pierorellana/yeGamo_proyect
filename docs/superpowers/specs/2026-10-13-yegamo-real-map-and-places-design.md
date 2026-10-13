# yeGamo — mapa real y búsqueda pública de lugares

**Fecha:** 2026-10-13
**Estado:** aprobado para implementación
**Ámbito:** cliente Flutter, gateway de proveedores NestJS y contrato HTTP de lugares

## Objetivo

Reemplazar en la ejecución normal el mapa ilustrado estático por un mapa real
basado en MapLibre, conservar el lenguaje visual de yeGamo mediante un estilo
configurable y habilitar búsquedas manuales de lugares usando Nominatim detrás
del gateway de geocodificación.

## Decisiones

- El renderizador Flutter será `maplibre_gl`; MapLibre no se considera una
  fuente de datos y el estilo/tiles se configuran por entorno.
- La configuración de ejecución usará por defecto un estilo inline con tiles
  raster de OpenStreetMap y atribución visible, para que el mapa tenga una
  superficie usable aunque un estilo vectorial remoto no responda. Este
  fallback está limitado a desarrollo y pruebas manuales de bajo volumen.
- OpenFreeMap Positron, basado en datos OSM y sin API key, queda disponible
  como estilo remoto configurable mediante `YEGAMO_MAP_STYLE_URL`. Si un
  estilo remoto no completa su carga, Flutter cambiará automáticamente al
  estilo raster fallback sin bloquear la pantalla.
- El backend consumirá Nominatim desde `GeocodingProvider`, nunca Flutter
  directamente. La consulta será explícita por acción del usuario, con límite
  local de una solicitud por segundo, caché en memoria de corta duración y
  `User-Agent` identificable.
- Nominatim no se usará para autocompletado, consultas sistemáticas ni
  geocodificación masiva.
- La activación de Nominatim será por configuración: habilitada por defecto en
  entornos no productivos y deshabilitada por defecto en producción.
- Google Places no forma parte de esta implementación; el gateway conservará
  el punto de extensión para añadirlo posteriormente sin cambiar Flutter.
- El mapa mostrará ubicación concedida, paradas del endpoint de cercanía y
  resultados de búsqueda. La ubicación precisa se usa en memoria y no se
  persiste.
- El mapa ilustrado existente se conserva como fallback de pruebas o cuando
  `YEGAMO_REAL_MAP=false`; no se eliminan sus fixtures de referencia.

## Contrato canónico

`Place` tendrá `id`, `label`, `location`, `source` y `dataState`. El `id` puede
ser el identificador externo del proveedor y por eso no se restringirá a UUID.
Un resultado Nominatim autorizado se marcará `dataState: CURRENT` y
`source: openstreetmap-nominatim`; un resultado demo se marcará `DEGRADED` y no
expondrá una fuente autorizada.

El modelo Flutter debe consumir `label` como nombre canónico y preservar las
coordenadas de cada lugar. Las paradas cercanas también deben conservar
`location`, no solo nombre y distancia.

## Mapa y estilo

El host persistente `YgMapHost` seguirá siendo el límite de integración para
las pantallas. En ejecución normal montará `YgRealMap`, que recibirá el estado
de `YgMapScope`, `NearbyViewModel` y `SearchViewModel` para pintar capas
dinámicas sin exponer DTOs de proveedores en las páginas.

El estilo puede recibirse con `YEGAMO_MAP_STYLE_URL`. Si está vacío, el mapa
usará un estilo inline de bajo volumen con tiles raster OSM y una capa visual
de yeGamo para marcadores. No se versionan claves ni tokens.

## Corrección de composición y búsqueda sobre túnel

Las superficies flotantes que se dibujan sobre `YgRealMap` no usarán
`BackdropFilter`: MapLibre se renderiza como una vista nativa y, en iOS, ese
filtro puede terminar difuminando toda la vista del mapa aunque el widget esté
recortado a una píldora o un panel. Se conservarán el fondo translúcido, el
borde y la sombra; el desenfoque queda reservado para superficies que no se
superponen al mapa nativo.

La pantalla de búsqueda mantendrá una consulta explícita mediante Buscar o
Enter. No se implementará autocomplete por cada tecla porque Nominatim no lo
permite bajo la política de uso público. Cuando el dispositivo tenga permiso
de ubicación, Flutter enviará latitud y longitud solo como parámetros
transitorios de la consulta; si no, el gateway limitará la búsqueda a Ecuador
y, cuando exista coordenada, usará una ventana alrededor del origen para
priorizar resultados cercanos a Guayaquil. Las coordenadas no se persistirán.

El timeout interno del gateway de geocodificación será de 5 segundos para
tolerar la latencia combinada de Nominatim y un túnel de desarrollo. El
ViewModel ignorará respuestas de solicitudes anteriores para que una búsqueda
vieja no reemplace los resultados de la consulta vigente. El panel no saltará
automáticamente a su altura máxima al enfocar el campo; permanecerá en estado
medio y se restaurará a ese estado al terminar la consulta.

## Fuera de alcance

- Google Maps/Places, rutas de navegación externas y autocompletado.
- Persistencia de resultados externos como catálogo propio.
- Cambios al esquema PostgreSQL/PostGIS; los lugares externos no se guardan.
- Uso de tiles públicos OSM como garantía de disponibilidad productiva.

## Criterios de aceptación

1. El mapa real aparece en la app ejecutada con `AppConfig.fromEnvironment()`
   sin requerir una API key de Google; por defecto usa el fallback raster y
   puede cambiarse a un estilo remoto con `YEGAMO_MAP_STYLE_URL`.
2. El mapa conserva atribución visible de OpenStreetMap cuando usa el fallback
   OSM y permite reemplazar el estilo por `YEGAMO_MAP_STYLE_URL`.
3. Las paradas cercanas del API se dibujan con sus coordenadas reales y
   `dataState`; no se vuelven a usar posiciones hardcodeadas del painter.
4. Una búsqueda manual válida devuelve lugares reales desde Nominatim cuando
   el proveedor está habilitado y el API puede alcanzarlo.
5. La respuesta de lugares conserva únicamente el contrato canónico y no
   filtra campos DTO de Nominatim.
6. Flutter muestra `label`, coordenadas y estado/fuente honestos; no presenta
   todos los lugares como “fuente autorizada”.
7. Las pruebas cubren rate limit local, parsing de Nominatim, mapping canónico,
   configuración del proveedor, parsing de coordenadas y capas de mapa.
8. `npm run typecheck`, pruebas API, `fvm flutter analyze`, pruebas Flutter y
   `git diff --check` pasan sin crear commits.
9. Inicio, Planificador y las pantallas de mapa mantienen el mapa nítido; una
   búsqueda manual de `terminal` muestra resultados canónicos de lugares o un
   estado de error accionable, sin un panel que oculte el campo al abrir el
   teclado.

## Verificación manual

```bash
cd api
NOMINATIM_ENABLED=true \
NOMINATIM_USER_AGENT='yeGamo-local-dev/1.0' \
PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH \
npm run start:dev
```

En Flutter:

```bash
cd yegamo_app
fvm flutter run -d <device> \
  --dart-define=YEGAMO_ENV=development \
  --dart-define=YEGAMO_REAL_MAP=true \
  --dart-define=YEGAMO_DEMO_DATA=true \
  --dart-define=YEGAMO_API_BASE_URL=https://URL_DEL_TUNEL
```

La política oficial de tiles OSM exige atribución visible, identificación de
la aplicación y uso moderado; Nominatim exige como máximo una solicitud por
segundo y prohíbe autocompletado. Estas restricciones forman parte del diseño,
no son detalles opcionales de despliegue.
