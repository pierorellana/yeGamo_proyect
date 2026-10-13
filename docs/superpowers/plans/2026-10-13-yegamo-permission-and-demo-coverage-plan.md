# yeGamo Permission and Demo Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delegar la solicitud de ubicación al permiso nativo del sistema y hacer visible el catálogo demo para invitados dentro de un radio de desarrollo explícito.

**Architecture:** `PermissionsPage` seguirá explicando el uso de ubicación, pero llamará directamente a `PermissionViewModel.request`, que delega en `geolocator`; se elimina el widget que simula iOS y se declaran los permisos foreground nativos. `AppConfig.demoDataEnabled` definirá el radio de consulta: 3000 m para el fixture demo y 1000 m en el resto de entornos, siempre usando coordenadas reales o un origen manual.

**Tech Stack:** Flutter/Dart, `geolocator`, `provider`, Flutter Test, NestJS API existente y contrato REST `/v1/transit/stops/nearby`.

## Global Constraints

- No realizar commits nuevos hasta instrucción explícita del usuario.
- No persistir coordenadas precisas; solo usarlas en memoria para la consulta.
- No imitar el diálogo de permisos del sistema operativo dentro de Flutter.
- Declarar `NSLocationWhenInUseUsageDescription` en iOS y `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` en Android.
- `YEGAMO_DEMO_DATA=true` solo amplía el radio del fixture sintético; no sustituye la ubicación real ni publica datos como `LIVE`.
- Mantener la opción de origen manual y los estados recuperables cuando el permiso sea denegado o el servicio esté desactivado.
- Ejecutar pruebas focalizadas, `flutter analyze`, la suite Flutter y `git diff --check`.

---

### Task 1: Capturar las regresiones de permiso nativo y radio demo

**Files:**
- Modify: `yegamo_app/test/modules/onboarding/entry_flow_test.dart`
- Modify: `yegamo_app/test/modules/permissions/permissions_page_test.dart`
- Modify: `yegamo_app/test/modules/home/home_test.dart`
- Create or modify: `yegamo_app/test/modules/nearby/nearby_test.dart`

**Interfaces:**
- Consumes: `TaskFiveApp`, `PermissionPage`, `AppConfig`, `HomeRepository` y `NearbyRepository`.
- Produces: pruebas que fallen si aparece la alerta simulada o si el modo demo conserva el radio productivo de 1000 m.

- [ ] **Step 1: Cambiar la prueba de onboarding para esperar la solicitud directa**

  En `entry_flow_test.dart`, reemplazar el bloque que pulsa
  `permission_allow`, busca `permission_dialog_allow` y espera la alerta por:

  ```dart
  await tester.tap(find.byKey(const ValueKey('permission_allow')));
  await tester.pumpAndSettle();
  expect(await storage.read('location_permission_result'), 'granted');
  expect(find.text('¿Usamos tu ubicación?'), findsNothing);
  expect(find.byKey(const ValueKey('permission_dialog_allow')), findsNothing);
  ```

- [ ] **Step 2: Cambiar la prueba de permiso denegado para pulsar una sola acción**

  En `permissions_page_test.dart`, eliminar la búsqueda de
  `permission_dialog_once` y dejar la interacción como:

  ```dart
  await tester.tap(find.byKey(const ValueKey('permission_allow')));
  await tester.pumpAndSettle();

  expect(find.text('Puedes continuar con un origen manual.'), findsOneWidget);
  expect(find.byKey(const ValueKey('permission_manual')), findsOneWidget);
  expect(await storage.read('precise_location'), isNull);
  ```

- [ ] **Step 3: Agregar la expectativa de radio demo en Home**

  Añadir una prueba con `AppConfig(demoDataEnabled: true)` que construya
  `HomeRepository`, use una posición fake `(-2.17, -79.9)` y compruebe que la
  única petición tiene:

  ```dart
  expect(request.uri.queryParameters['radiusM'], '3000');
  ```

  Mantener la prueba existente de configuración normal esperando `1000`.

- [ ] **Step 4: Agregar la expectativa equivalente en Nearby**

  Añadir un transporte capturable a `NearbyRepository` con `AppConfig` demo y
  comprobar que solicita `/v1/transit/stops/nearby` con `radiusM=3000`.

- [ ] **Step 5: Ejecutar las pruebas en rojo**

  Desde `yegamo_app/` ejecutar:

  ```bash
  fvm flutter test \
    test/modules/onboarding/entry_flow_test.dart \
    test/modules/permissions/permissions_page_test.dart \
    test/modules/home/home_test.dart \
    test/modules/nearby/nearby_test.dart
  ```

  Resultado esperado antes de la implementación: las pruebas de permiso aún
  encuentran la alerta simulada y la prueba demo aún recibe el radio de 1000 m.

### Task 2: Delegar el permiso al sistema operativo

**Files:**
- Modify: `yegamo_app/lib/modules/permissions/pages/permissions_page.dart`
- Delete from runtime: `yegamo_app/lib/modules/permissions/widgets/ios_location_dialog.dart`
- Modify: `yegamo_app/ios/Runner/Info.plist`
- Modify: `yegamo_app/android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: `PermissionViewModel.request()` y `PermissionRepository.requestWhileInUse()`.
- Produces: botón `permission_allow` que invoca una sola vez el permiso nativo y página sin `permission_dialog_*`.

- [ ] **Step 1: Eliminar el estado y la ruta de la alerta simulada**

  En `_PermissionsPageState`, quitar `bool _dialog`, `_deny()`, el import de
  `ios_location_dialog.dart` y el `if (_dialog)` del `Stack`.

- [ ] **Step 2: Conectar el botón principal con la solicitud nativa**

  Cambiar la construcción de `_Sheet` de:

  ```dart
  onAllow: () => setState(() => _dialog = true),
  ```

  a:

  ```dart
  onAllow: _request,
  ```

  `_request` conservará la llamada existente a
  `PermissionViewModel.request()`, la navegación a Home cuando el resultado
  sea `granted` y el estado recuperable cuando sea denegado.

- [ ] **Step 3: Eliminar el widget de alerta simulada**

  Borrar `ios_location_dialog.dart` porque ya no tendrá consumidores. No
  cambiar `LocationService`: `GeolocatorLocationService.requestWhileInUse()`
  ya usa `Geolocator.requestPermission()` y la configuración nativa existente
  conserva `NSLocationWhenInUseUsageDescription`.

- [ ] **Step 4: Ejecutar las pruebas de permiso**

  ```bash
  fvm flutter test \
    test/modules/onboarding/entry_flow_test.dart \
    test/modules/permissions/permissions_page_test.dart
  ```

  Resultado esperado: PASS y ausencia del texto/widget
  `permission_dialog_allow`.

- [ ] **Step 5: Declarar permisos foreground nativos**

  En `ios/Runner/Info.plist`, dentro de `<dict>`, añadir:

  ```xml
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>yeGamo usa tu ubicación mientras la app está abierta para encontrar paradas cercanas.</string>
  ```

  En `android/app/src/main/AndroidManifest.xml`, como hijos directos de
  `<manifest>`, añadir:

  ```xml
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
  ```

  No añadir permisos de ubicación en segundo plano.

### Task 3: Aplicar radio de consulta según el entorno

**Files:**
- Modify: `yegamo_app/lib/modules/home/services/home_repository.dart`
- Modify: `yegamo_app/lib/modules/nearby/services/nearby_repository.dart`
- Modify: `yegamo_app/lib/modules/onboarding/task_five_app.dart`
- Modify: `yegamo_app/test/modules/home/home_test.dart`
- Modify: `yegamo_app/test/modules/nearby/nearby_test.dart`

**Interfaces:**
- Consumes: `AppConfig.demoDataEnabled`, `LocationService.currentPosition()` y `ApiClient.get()`.
- Produces: `radiusM=3000` solo con demo explícito y `radiusM=1000` en desarrollo normal/producción.

- [ ] **Step 1: Inyectar `AppConfig` en ambos repositorios**

  Añadir `required AppConfig config` a los constructores de
  `HomeRepository` y `NearbyRepository`, conservarlo como campo privado y
  pasar `config` desde `TaskFiveScope`:

  ```dart
  HomeRepository(
    apiClient: context.read<ApiClient>(),
    connectivity: context.read<ConnectivityService>(),
    storage: context.read<LocalStorage>(),
    locationService: context.read<LocationService>(),
    session: context.read<SessionManager>(),
    config: config,
  )
  ```

  Para `NearbyRepository`, pasar el mismo `config`.

- [ ] **Step 2: Centralizar el radio en cada repositorio**

  Usar esta propiedad privada en ambos repositorios:

  ```dart
  String get _nearbyRadiusM => _config.demoDataEnabled ? '3000' : '1000';
  ```

  Reemplazar el literal de `radiusM` por `_nearbyRadiusM`. Las coordenadas
  deben seguir viniendo de `currentPosition()` o `manualOrigin`.

- [ ] **Step 3: Formatear y ejecutar pruebas focalizadas**

  ```bash
  fvm dart format \
    lib/modules/permissions/pages/permissions_page.dart \
    lib/modules/home/services/home_repository.dart \
    lib/modules/nearby/services/nearby_repository.dart \
    lib/modules/onboarding/task_five_app.dart \
    test/modules/onboarding/entry_flow_test.dart \
    test/modules/permissions/permissions_page_test.dart \
    test/modules/home/home_test.dart \
    test/modules/nearby/nearby_test.dart

  fvm flutter test \
    test/modules/onboarding/entry_flow_test.dart \
    test/modules/permissions/permissions_page_test.dart \
    test/modules/home/home_test.dart \
    test/modules/nearby/nearby_test.dart
  ```

### Task 4: Verificación final y prueba con el túnel

**Files:**
- Modify: `docs/superpowers/specs/2026-10-13-yegamo-local-tunnel-data-vertical-design.md` (ya actualizado antes de implementar)
- No modificar: `api/.env`, URLs públicas o credenciales

**Interfaces:**
- Consumes: API local, Dev Tunnel HTTPS y configuración `--dart-define`.
- Produces: app lista para probar el permiso nativo y el catálogo demo como invitado.

- [ ] **Step 1: Ejecutar análisis y toda la suite Flutter**

  ```bash
  fvm flutter analyze
  fvm flutter test
  ```

- [ ] **Step 2: Validar el API por el túnel**

  ```bash
  curl -i https://9hqbzkgw-3000.use.devtunnels.ms/v1/health
  curl -i 'https://9hqbzkgw-3000.use.devtunnels.ms/v1/transit/stops/nearby?lat=-2.155&lon=-79.895&radiusM=3000'
  ```

  Ambos deben responder 200; la segunda respuesta debe conservar
  `dataState: DEGRADED`.

- [ ] **Step 3: Ejecutar `git diff --check` y revisar el estado**

  ```bash
  git diff --check
  git status --short
  ```

  No crear commit. Mantener `.claude/` y `yegamo_app/.fvm/` sin alterarlos.
