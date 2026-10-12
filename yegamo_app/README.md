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
  --dart-define=YEGAMO_DEMO_DATA=true
```

`YEGAMO_DEMO_DATA` no se acepta cuando `YEGAMO_ENV=production`. La App no
autoriza por sí misma una fuente de transporte, no publica `LIVE` sin fuente y
timestamp, y no persiste ubicación precisa sin consentimiento.

## Estructura

```text
lib/env/          configuración y tema
lib/shared/       contrato HTTP, estado, ubicación, navegación y componentes
lib/modules/      onboarding, descubrimiento, planificación, viaje y retención
test/fixtures/    fixtures deterministas sólo para pruebas
integration_test/ flujos baseline con transporte falso
```
