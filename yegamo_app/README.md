# yeGamo Flutter App

Cliente Flutter modular de yeGamo. Conserva la baseline de exactamente 17
rutas y 9 estados UX; `arrived` y `nocov` son estados del flujo, no pantallas.

## Desarrollo local

Desde `yegamo_app/`:

```bash
flutter pub get
flutter analyze
flutter test
```

La prueba de integración completa está en
`integration_test/full_baseline_flow_test.dart` y usa únicamente reloj,
transporte y payloads falsos de test. Un runner de dispositivo o emulador es
una precondición externa:

```bash
flutter test integration_test/full_baseline_flow_test.dart
```

Si el runner no está disponible, el resultado debe registrarse como `NOT RUN`,
no como pase. Los checks estables de semántica y constraints están en
`test/goldens/`; no hay imágenes golden versionadas porque el proyecto aún no
configura un runner de goldens ni un proceso de actualización aprobado.

## Configuración honesta de datos

La configuración por defecto no habilita datos demo. Para un entorno local de
desarrollo se puede activar explícitamente:

```bash
flutter run \
  --dart-define=YEGAMO_ENV=development \
  --dart-define=YEGAMO_DEMO_DATA=true \
  --dart-define=YEGAMO_REAL_MAP=true
```

`YEGAMO_DEMO_DATA` no se acepta cuando `YEGAMO_ENV=production`. La App no
autoriza por sí misma una fuente de transporte, no publica `LIVE` sin fuente y
timestamp, y no persiste ubicación precisa sin consentimiento.

El mapa real usa MapLibre con un fallback raster de OpenStreetMap por defecto,
sin API key, para evitar que un estilo remoto deje la superficie en blanco. El
estilo y la URL de tiles se pueden cambiar en tiempo de ejecución. OpenFreeMap
Positron queda disponible como estilo remoto opcional:

```bash
fvm flutter run \
  --dart-define=YEGAMO_REAL_MAP=true \
  --dart-define=YEGAMO_MAP_STYLE_URL=https://URL_DEL_ESTILO_MAPLIBRE \
  --dart-define=YEGAMO_MAP_TILE_URL=https://tile.openstreetmap.org/{z}/{x}/{y}.png
```

La búsqueda de lugares sugiere resultados después de 500 ms sin cambios y con
al menos tres caracteres. El backend consulta Nominatim respetando su límite
de una solicitud por segundo y la app muestra la fuente/estado recibido.

## API local mediante túnel HTTPS

Para probar el iPhone conectado por datos móviles, levanta el API con
Nominatim y Overpass habilitados, reenvía el puerto `3000` desde la vista **Ports**
de VS Code con visibilidad **Public** y copia la URL HTTPS. Después ejecuta:

```bash
export YEGAMO_TUNNEL_URL='https://URL_PUBLICA_COPIADA_DE_VS_CODE'
fvm flutter run -d 00008140-001461680A7B801C \
  --dart-define=YEGAMO_ENV=development \
  --dart-define=YEGAMO_DEMO_DATA=false \
  --dart-define=YEGAMO_REAL_MAP=true \
  --dart-define=YEGAMO_API_BASE_URL="$YEGAMO_TUNNEL_URL"
```

`YEGAMO_API_BASE_URL` solo se inyecta en la ejecución y no debe guardarse en
este repositorio. En sesión invitada, favoritos, rutinas y notificaciones se
mantienen en almacenamiento local; las capacidades que requieren identidad
OIDC no se simulan.

## Estructura

```text
lib/env/          configuración y tema
lib/shared/       contrato HTTP, estado, ubicación, navegación y componentes
lib/modules/      onboarding, descubrimiento, planificación, viaje y retención
test/fixtures/    fixtures deterministas sólo para pruebas
integration_test/ flujos baseline con transporte falso
```


## Configuración de compilación (`--dart-define`)

| Define | Uso |
|---|---|
| `YEGAMO_ENV` | `development` \| `staging` \| `production` (en producción nunca se muestran datos demo) |
| `YEGAMO_API_BASE_URL` | URL base del API (HTTPS en staging/producción) |
| `YEGAMO_DEMO_DATA` | Solo desarrollo: catálogo demo y overlays del mapa |
| `YEGAMO_REAL_MAP`, `YEGAMO_MAP_STYLE_URL`, `YEGAMO_MAP_TILE_URL` | Mapa |
| `YEGAMO_OIDC_TOKEN_ENDPOINT`, `YEGAMO_OIDC_CLIENT_ID` | Renovación de sesión OIDC (valores públicos). Vacíos = sin inicio de sesión: la app opera como invitado |

Los datos de transporte vienen siempre del API; sin proveedor la app muestra
«no disponible» en lugar de inventar rutas, horarios o ETA (ADR-010).
