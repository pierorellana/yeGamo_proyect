# yeGamo Real Map and Places Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use inline execution for this plan because the user requested implementation in the current workspace. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mostrar un mapa real configurable en yeGamo, pintar sobre él las paradas y lugares encontrados, y habilitar búsquedas manuales mediante Nominatim detrás del gateway de proveedores.

**Architecture:** El host persistente de mapas conservará la API declarativa existente (`YgMapView`/`YgMapScope`) y elegirá `YgRealMap` en ejecución normal, dejando `YgMap` como fallback controlable para tests y entornos sin mapa real. El API incorporará un adaptador Nominatim bajo `GeocodingGatewayService`, limitará y cacheará las consultas explícitas, y devolverá solo el contrato canónico `Place`.

**Tech Stack:** Flutter/Dart, `maplibre_gl` 0.27.1, MapLibre style JSON, OpenFreeMap Positron vector style sin API key con fallback OSM raster de bajo volumen, NestJS 11, Node 20 `fetch`, Nominatim, Flutter Test, Jest/Supertest.

## Global Constraints

- No realizar commits nuevos hasta instrucción explícita del usuario.
- No versionar claves, tokens, URLs de túnel ni credenciales.
- No persistir coordenadas precisas; ubicación y centros de mapa se mantienen en memoria.
- Nominatim solo se consulta por acción explícita del usuario, máximo una solicitud por segundo y nunca para autocompletado.
- El backend decide `dataState` y `source`; Flutter no inventa estados ni presenta todos los resultados como autorizados.
- La atribución `© OpenStreetMap contributors` debe ser visible cuando se usa el fallback OSM.
- `YEGAMO_REAL_MAP=false` conserva el mapa ilustrado para tests; `AppConfig.fromEnvironment()` habilita el mapa real por defecto y usa el estilo raster OSM inline salvo que se configure `YEGAMO_MAP_STYLE_URL`.
- Ejecutar pruebas focalizadas, suites completas aplicables, `flutter analyze`, typecheck/build del API y `git diff --check`.

---

### Task 1: Congelar el contrato y la configuración del mapa

**Files:**
- Modify: `api/src/provider-gateway/domain/provider.types.ts`
- Modify: `api/contracts/openapi.yaml`
- Modify: `yegamo_app/lib/env/config/app_config.dart`
- Modify: `yegamo_app/pubspec.yaml`
- Test: `yegamo_app/test/env/app_config_test.dart` (crear si no existe)

**Interfaces:**
- Produces `Place.dataState: DataState` and provider IDs as strings.
- Produces `AppConfig.realMapEnabled`, `AppConfig.mapStyleUrl` and `AppConfig.mapTileUrl`.
- Adds the `maplibre_gl` dependency without adding a Google API key.

- [ ] **Step 1: Escribir pruebas de configuración que fallen**

  Crear `yegamo_app/test/env/app_config_test.dart` con pruebas que construyan
  `const AppConfig()` y verifiquen que el fallback de tests no monte MapLibre,
  y que `AppConfig.fromEnvironment()` pueda leer `YEGAMO_REAL_MAP` mediante la
  configuración de compilación. Como `String.fromEnvironment` no se puede
  mutar durante una prueba, la prueba unitaria debe cubrir los valores de la
  constante y la prueba de runtime se verificará con `flutter run`.

  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:yegamo_app/env/config/app_config.dart';

  void main() {
    test('test config conserva el mapa ilustrado por defecto', () {
      const config = AppConfig();

      expect(config.realMapEnabled, isFalse);
      expect(config.mapStyleUrl, isEmpty);
      expect(config.mapTileUrl, contains('{z}/{x}/{y}'));
    });
  }
  ```

- [ ] **Step 2: Actualizar el tipo Place y OpenAPI**

  En `provider.types.ts`, importar el tipo existente `DataState` local y
  extender `Place`:

  ```ts
  export interface Place {
    id: string;
    label: string;
    location: GeoPoint;
    source: string | null;
    dataState: DataState;
  }
  ```

  En `api/contracts/openapi.yaml`, cambiar `Place.id` para que sea `type:
  string` sin `format: uuid`, añadir `dataState` como requerido y conservar
  `source` nullable. El esquema resultante debe declarar:

  ```yaml
  Place:
    type: object
    required: [id, label, location, dataState]
    properties:
      id: { type: string }
      label: { type: string, example: Centro de Guayaquil }
      location: { $ref: '#/components/schemas/GeoPoint' }
      source: { type: string, nullable: true, example: openstreetmap-nominatim }
      dataState: { $ref: '#/components/schemas/DataState' }
  ```

- [ ] **Step 3: Añadir configuración explícita del mapa**

  En `AppConfig`, añadir estos campos y hacer que `fromEnvironment()` los
  llene sin secretos por defecto:

  ```dart
  const AppConfig({
    this.apiBaseUrl = 'http://localhost:3000',
    this.environment = AppEnvironment.development,
    this.demoDataEnabled = false,
    this.reduceMotion = false,
    this.realMapEnabled = false,
    this.mapStyleUrl = '',
    this.mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.requestTimeout = const Duration(seconds: 15),
    this.maxRetries = 1,
  });
  ```

  `fromEnvironment()` debe usar `YEGAMO_REAL_MAP` con valor por defecto
  `true`, `YEGAMO_MAP_STYLE_URL` con valor vacío y
  `YEGAMO_MAP_TILE_URL` con la URL OSM anterior. La constante por defecto
  permanece `false` para que los tests que crean `const AppConfig()` sigan
  usando el painter determinista.

- [ ] **Step 4: Añadir `maplibre_gl`**

  En `yegamo_app/pubspec.yaml`, añadir dentro de `dependencies`:

  ```yaml
  maplibre_gl: ^0.27.1
  ```

  Ejecutar `fvm flutter pub get` y conservar los cambios de `pubspec.lock`.
  No añadir `google_maps_flutter` ni claves de Google.

- [ ] **Step 5: Verificar la tarea**

  ```bash
  cd yegamo_app
  fvm flutter test test/env/app_config_test.dart
  fvm flutter analyze
  ```

  Resultado esperado: PASS y sin warnings nuevos.

### Task 2: Implementar Nominatim detrás del gateway

**Files:**
- Create: `api/src/provider-gateway/adapters/nominatim-geocoding.provider.ts`
- Modify: `api/src/provider-gateway/application/geocoding-gateway.service.ts`
- Modify: `api/src/provider-gateway/provider-gateway.module.ts`
- Modify: `api/src/provider-gateway/domain/provider.types.ts`
- Test: `api/test/provider-gateway/nominatim-geocoding.provider.spec.ts`
- Modify: `api/test/places/places.spec.ts`

**Interfaces:**
- `NominatimGeocodingProvider implements GeocodingProvider`.
- Constructor: `new NominatimGeocodingProvider(options?: { baseUrl?: string; userAgent?: string; fetcher?: typeof fetch; now?: () => Date })`.
- `search(query: string, near?: GeoPoint): Promise<ProviderResult<RawPlace[]>>`.
- `reverse(point: GeoPoint): Promise<ProviderResult<RawPlace>>`.
- `GeocodingGatewayService` returns canonical `Place[]` with `dataState`.

- [ ] **Step 1: Escribir pruebas del adaptador Nominatim**

  El fake fetcher debe comprobar URL, `Accept`, `User-Agent`, parsear dos
  resultados válidos y descartar una respuesta inválida mediante
  `ProviderGatewayError`.

  ```ts
  it('maps search results without leaking Nominatim fields', async () => {
    const fetcher = jest.fn<typeof fetch>().mockResolvedValue(
      new Response(JSON.stringify([
        { place_id: 10, osm_type: 'node', osm_id: 20, display_name: 'Malecón 2000', lat: '-2.19', lon: '-79.88' },
      ]), { status: 200 }),
    );
    const provider = new NominatimGeocodingProvider({
      baseUrl: 'https://nominatim.test',
      userAgent: 'yeGamo-test/1.0',
      fetcher,
    });

    const result = await provider.search('Malecon');

    expect(result.providerKey).toBe('openstreetmap-nominatim');
    expect(result.sourceAuthorized).toBe(true);
    expect(result.data).toEqual([
      {
        id: 'nominatim:10',
        label: 'Malecón 2000',
        location: { lat: -2.19, lon: -79.88 },
      },
    ]);
    expect(fetcher).toHaveBeenCalledWith(
      expect.stringContaining('/search?'),
      expect.objectContaining({ headers: expect.objectContaining({ 'User-Agent': 'yeGamo-test/1.0' }) }),
    );
  });

  it('limits explicit searches to one request per second', async () => {
    const fetcher = jest.fn<typeof fetch>().mockResolvedValue(
      new Response('[]', { status: 200 }),
    );
    const provider = new NominatimGeocodingProvider({
      baseUrl: 'https://nominatim.test',
      userAgent: 'yeGamo-test/1.0',
      fetcher,
      now: () => new Date('2026-10-13T12:00:00.000Z'),
    });

    await provider.search('Centro');
    await expect(provider.search('Malecon')).rejects.toMatchObject({
      code: 'PROVIDER_UNAVAILABLE',
      retryable: true,
    });
    expect(fetcher).toHaveBeenCalledTimes(1);
  });
  ```

- [ ] **Step 2: Implementar la respuesta segura del proveedor**

  El adaptador debe solicitar únicamente `format=jsonv2`, `limit=8` y
  `accept-language=es`; reverse usará `format=jsonv2` y `zoom=18`. El método
  `toRawPlace` solo copiará `place_id`, `display_name`, `lat` y `lon` a
  `{id,label,location}`. No se enviará el texto de búsqueda ni coordenadas
  precisas a otro lugar fuera de la consulta solicitada.

  Las respuestas HTTP no 2xx, JSON no-array/no-object o coordenadas inválidas
  deben lanzar `ProviderGatewayError` con `capability: 'geocoding'` y
  `providerKey: 'openstreetmap-nominatim'`. El rate limiter debe ser por
  instancia y rechazar solicitudes que no hayan esperado un segundo desde la
  última solicitud.

- [ ] **Step 3: Mapear `dataState` en el gateway**

  En `mapPlaces`, devolver:

  ```ts
  return {
    id: value.id,
    label: value.label,
    location: { lat: value.location.lat, lon: value.location.lon },
    source: !result.isDemo && result.sourceAuthorized === true
      ? result.providerKey
      : null,
    dataState: !result.isDemo && result.sourceAuthorized === true
      ? 'CURRENT'
      : 'DEGRADED',
  };
  ```

- [ ] **Step 4: Registrar el proveedor solo cuando corresponda**

  En `ProviderGatewayModule`, reemplazar el `useValue: []` por un factory que
  reciba `ConfigService` y cree `[new NominatimGeocodingProvider(...)]` cuando
  `NOMINATIM_ENABLED` sea `true` o cuando `NODE_ENV` no sea `production` y la
  variable esté ausente. En producción, solo se registra si
  `NOMINATIM_ENABLED=true`. El `NOMINATIM_BASE_URL` por defecto es
  `https://nominatim.openstreetmap.org` y el `NOMINATIM_USER_AGENT` por defecto
  es `yeGamo-local-dev/1.0`; producción debe exigir un valor explícito y
  devolver lista vacía si falta.

- [ ] **Step 5: Actualizar pruebas de places**

  Mantener la prueba de 503 cuando se sobreescribe el token con `[]`. Actualizar
  la prueba de éxito autorizado para esperar `dataState: 'CURRENT'`. Añadir una
  prueba con un proveedor `isDemo: true` que espere `source: null` y
  `dataState: 'DEGRADED'`. Verificar que la respuesta no tenga `providerKey`,
  `observedAt`, `display_name` ni `osm_type`.

- [ ] **Step 6: Ejecutar API focalizado**

  ```bash
  cd api
  PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm test -- --runInBand --watchman=false test/places/places.spec.ts test/provider-gateway/nominatim-geocoding.provider.spec.ts
  PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm run typecheck
  ```

  Resultado esperado: todas las pruebas PASS y typecheck PASS.

### Task 3: Conservar coordenadas y estados en modelos Flutter

**Files:**
- Modify: `yegamo_app/lib/modules/nearby/models/nearby_models.dart`
- Modify: `yegamo_app/lib/modules/nearby/services/nearby_repository.dart`
- Modify: `yegamo_app/lib/modules/search/models/search_models.dart`
- Modify: `yegamo_app/lib/modules/search/pages/search_page.dart`
- Test: `yegamo_app/test/modules/nearby/nearby_test.dart`
- Modify: `yegamo_app/test/modules/search/search_test.dart`

**Interfaces:**
- `NearbyStop` adds `latitude` and `longitude`.
- `NearbySnapshot` adds `GeoCoordinate? origin`.
- `PlaceResult` reads `label` first, retains `source`, and keeps `dataState`.

- [ ] **Step 1: Escribir pruebas de parsing antes del cambio**

  Añadir a las pruebas existentes un payload de parada con `location` y
  comprobar que el resultado conserva latitud/longitud. Añadir un payload de
  lugar con `label`, `source` y `dataState` y comprobar que `name` queda igual
  a `label`.

  ```dart
  test('preserves nearby stop coordinates for the map', () async {
    final snapshot = await NearbyRepository(
      apiClient: testClient((_) async => jsonResponse([
        {
          'id': 'stop-1',
          'name': 'Parada Centro',
          'location': {'lat': -2.17, 'lon': -79.90},
          'distanceM': 120,
          'dataState': 'DEGRADED',
        },
      ])),
      connectivity: FakeConnectivityService(),
      locationService: FakeLocationService(
        position: const GeoCoordinate(latitude: -2.17, longitude: -79.90),
      ),
    ).load();

    expect(snapshot.stops.single.latitude, -2.17);
    expect(snapshot.stops.single.longitude, -79.90);
    expect(snapshot.origin?.latitude, -2.17);
  });
  ```

- [ ] **Step 2: Implementar parsing canónico de coordenadas**

  `NearbyStop.fromJson` debe leer `location.lat`/`location.lon`, aceptar
  números o strings, y usar `null` solo si la coordenada es inválida. El
  repositorio debe devolver `NearbySnapshot(origin: position, ...)` en las
  respuestas exitosas, vacías y degradadas cuando haya posición.

  `PlaceResult.fromJson` debe usar `json['label'] ?? json['name']` para
  compatibilidad temporal con fixtures antiguos, y leer `source` como
  `String?`. La UI debe mostrar:

  ```dart
  final subtitle = result.source == 'openstreetmap-nominatim'
      ? 'OpenStreetMap · lugares geocodificados'
      : result.dataState == DataState.degraded
          ? 'Datos limitados'
          : 'Lugar encontrado';
  ```

  Eliminar el texto fijo `Resultado de una fuente autorizada`.

- [ ] **Step 3: Mostrar resultados reales en el mapa y permitir selección**

  En `YgMapHost`, la lista de resultados del `SearchViewModel` se pasará a
  `YgRealMap`. Al pulsar un resultado, conservar el comportamiento actual de
  navegar al planificador y pasar el `PlaceResult` como argumento de ruta para
  que la siguiente tarea pueda precargar el destino. No usar el DTO del API
  directamente en el widget del mapa.

- [ ] **Step 4: Ejecutar pruebas Flutter focalizadas**

  ```bash
  cd yegamo_app
  fvm flutter test test/modules/nearby/nearby_test.dart test/modules/search/search_test.dart
  fvm flutter analyze
  ```

### Task 4: Añadir el mapa real y las capas yeGamo

**Files:**
- Create: `yegamo_app/lib/shared/map/yg_real_map.dart`
- Create: `yegamo_app/lib/shared/map/yg_map_style.dart`
- Modify: `yegamo_app/lib/shared/map/yg_map_host.dart`
- Modify: `yegamo_app/lib/shared/map/yg_map_view.dart`
- Modify: `yegamo_app/lib/modules/onboarding/task_five_app.dart`
- Test: `yegamo_app/test/shared/map/yg_real_map_test.dart`

**Interfaces:**
- `YgRealMap({required YgMapView view, required AppConfig config, required LocationService locationService, required List<NearbyStop> stops, required List<PlaceResult> places})`.
- `YgMapStyle.fallback({required String tileUrl}) -> String` returns a valid MapLibre style JSON.
- `YgMapHost` chooses `YgRealMap` when `config.realMapEnabled`, otherwise current `YgMap`.

- [ ] **Step 1: Escribir pruebas de estilo y fallback**

  Crear `yg_real_map_test.dart` con una prueba que llame
  `YgMapStyle.fallback(tileUrl: ...)`, decodifique el JSON y compruebe que
  contiene una fuente raster con la URL recibida, una capa raster y no contiene
  tokens. Añadir una prueba de `YgMapHost` con `const AppConfig()` que siga
  encontrando el widget `YgMap` existente.

  ```dart
  test('fallback style uses configurable OSM raster tiles and attribution', () {
    final style = jsonDecode(
      YgMapStyle.fallback(tileUrl: 'https://tiles.test/{z}/{x}/{y}.png'),
    ) as Map<String, Object?>;
    final sources = style['sources'] as Map<String, Object?>;

    expect(sources['yegamo-base'], containsPair('type', 'raster'));
    expect(
      (sources['yegamo-base'] as Map)['tiles'],
      contains('https://tiles.test/{z}/{x}/{y}.png'),
    );
    expect(style['layers'], isNotEmpty);
  });
  ```

- [ ] **Step 2: Implementar el estilo inline**

  `YgMapStyle.fallback` debe devolver un JSON con `version: 8`, una fuente
  raster `yegamo-base`, una capa raster, fondo `#E8EEE8`, y metadato de
  atribución `© OpenStreetMap contributors`. La atribución también se
  renderizará como texto Flutter para que sea visible en iOS y Android.

- [ ] **Step 3: Implementar `YgRealMap`**

  Crear un `StatefulWidget` con `MapLibreMap` y estas reglas:

  - Usa `config.mapStyleUrl` cuando no esté vacío; si está vacío usa
    `YgMapStyle.fallback(tileUrl: config.mapTileUrl)`.
  - Inicia en la última posición disponible de `LocationService` o en
    `GeoPoint(-2.1700, -79.9000)` como centro visual de Guayaquil.
  - Solicita solo `currentPosition()` después de que el sistema ya haya
    concedido permiso; nunca llama `requestPermission()` desde el mapa.
  - Registra una fuente GeoJSON `yegamo-stops` y una capa de círculos para
    `NearbyStop`; registra `yegamo-places` y una capa distinta para
    `PlaceResult`.
  - Actualiza el GeoJSON en `didUpdateWidget` y después de
    `onStyleLoadedCallback`.
  - Usa colores del sistema yeGamo: paradas `#385C45`, lugares `#B86D3D`,
    borde blanco, y opacidad reducida cuando `dataState != CURRENT`.
  - Muestra en una posición fija y legible `© OpenStreetMap contributors`
    solo cuando usa el estilo fallback OSM.
  - Si el estilo remoto no termina de cargar, cambia automáticamente al
    estilo raster fallback; si también falla, muestra un `YgBanner`/overlay no
    bloqueante y deja los paneles de la pantalla funcionando.

  La representación GeoJSON debe tener esta forma, sin DTOs de proveedor:

  ```dart
  Map<String, Object?> pointFeature({
    required String id,
    required double latitude,
    required double longitude,
    required String kind,
    required String dataState,
  }) => <String, Object?>{
    'type': 'Feature',
    'id': id,
    'geometry': <String, Object?>{
      'type': 'Point',
      'coordinates': <double>[longitude, latitude],
    },
    'properties': <String, Object?>{
      'kind': kind,
      'dataState': dataState,
    },
  };
  ```

- [ ] **Step 4: Integrar el host persistente**

  En `YgMapHost`, leer con `context.watch` el `NearbyViewModel` y
  `SearchViewModel`, convertir sus modelos a las listas requeridas y montar:

  ```dart
  config.realMapEnabled
      ? YgRealMap(
          view: scope.view,
          config: config,
          locationService: context.read<LocationService>(),
          stops: nearby.snapshot.stops,
          places: search.snapshot.results,
        )
      : YgMap(
          view: scope.view,
          controller: scope.controller,
          showDemoOverlays: config.demoDataEnabled,
        )
  ```

  Mantener `YgMapController` para el fallback y no alterar los tests actuales
  del painter. El mapa real usará sus propios gestos nativos de MapLibre.

- [ ] **Step 5: Añadir pruebas de montaje sin plugin nativo**

  Las pruebas unitarias usarán `const AppConfig()` y verificarán el fallback
  ilustrado. La prueba del estilo será pura. No se intentará simular el
  `PlatformView` nativo de MapLibre en Flutter Test; la creación real se
  validará con `flutter build ios --no-codesign` y ejecución en el dispositivo.

- [ ] **Step 6: Formatear y verificar Flutter**

  ```bash
  cd yegamo_app
  fvm dart format lib/env/config/app_config.dart lib/shared/map/yg_real_map.dart lib/shared/map/yg_map_style.dart lib/shared/map/yg_map_host.dart lib/shared/map/yg_map_view.dart lib/modules/nearby/models/nearby_models.dart lib/modules/search/models/search_models.dart lib/modules/search/pages/search_page.dart test/shared/map/yg_real_map_test.dart test/modules/nearby/nearby_test.dart test/modules/search/search_test.dart
  fvm flutter test
  fvm flutter analyze
  fvm flutter build ios --no-codesign
  ```

### Task 5: Precargar lugares en Planner y documentar la ejecución

**Files:**
- Modify: `yegamo_app/lib/modules/planner/pages/planner_page.dart`
- Modify: `yegamo_app/lib/shared/navigation/app_routes.dart`
- Modify: `yegamo_app/README.md`
- Modify: `api/README.md`
- Modify: `docs/superpowers/specs/2026-10-13-yegamo-real-map-and-places-design.md`

**Interfaces:**
- Planner route arguments accept `PlaceResult` without importing API DTOs.
- `YEGAMO_REAL_MAP`, `YEGAMO_MAP_STYLE_URL`, `YEGAMO_MAP_TILE_URL`,
  `NOMINATIM_ENABLED` and `NOMINATIM_USER_AGENT` are documented as runtime
  configuration.

- [ ] **Step 1: Escribir prueba de selección de destino**

  Añadir a la prueba de búsqueda una interacción que pulse
  `result_place-1`, navegue a `AppRoutes.planner`, y compruebe que el campo de
  destino muestra el label recibido. La prueba debe usar:

  ```dart
  const PlaceResult(
    id: 'place-1',
    name: 'Lugar autorizado',
    latitude: -2.1,
    longitude: -79.9,
    dataState: DataState.current,
    source: 'openstreetmap-nominatim',
  )
  ```

- [ ] **Step 2: Pasar y consumir el argumento de ruta**

  En `SearchPage`, navegar con `arguments: result`. En `PlannerPage.initState`,
  leer `ModalRoute.of(context)?.settings.arguments` después de crear los
  controladores; si es `PlaceResult`, escribir su label en destino y conservar
  su coordenada en una variable `JourneyPoint? _argumentDestination`. En
  `_calculate`, usar esa coordenada cuando el texto no tenga formato manual
  `latitud, longitud`.

  No enviar el DTO completo al API: solo `JourneyPoint.toJson()` del contrato
  de viajes.

- [ ] **Step 3: Documentar configuración y límites**

  Añadir a ambos README comandos explícitos para el túnel, configuración del
  mapa y API:

  ```bash
  # API local
  NOMINATIM_ENABLED=true \
  NOMINATIM_USER_AGENT='yeGamo-local-dev/1.0' \
  npm run start:dev

  # Flutter conectado al túnel
  fvm flutter run -d <device> \
    --dart-define=YEGAMO_ENV=development \
    --dart-define=YEGAMO_REAL_MAP=true \
    --dart-define=YEGAMO_DEMO_DATA=true \
    --dart-define=YEGAMO_API_BASE_URL=https://URL_DEL_TUNEL
  ```

  Explicar que Nominatim no es autocomplete y que los tiles OSM públicos son
  un fallback de desarrollo con atribución, caché y bajo volumen.

- [ ] **Step 4: Ejecutar la verificación completa**

  ```bash
  cd api
  PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm test -- --runInBand --watchman=false
  PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm run typecheck
  PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm run build

  cd ../yegamo_app
  fvm flutter test
  fvm flutter analyze
  fvm flutter build ios --no-codesign

  cd ..
  git diff --check
  ```

- [ ] **Step 5: Verificar el túnel y el dispositivo**

  Con el API levantado, probar `GET /v1/health`,
  `GET /v1/places/search?q=Malecon` y
  `GET /v1/transit/stops/nearby?lat=-2.155&lon=-79.895&radiusM=3000` mediante
  la URL de túnel actual. Ejecutar la app en el iPhone con `YEGAMO_REAL_MAP=true`,
  comprobar que se ven tiles, atribución, paradas y resultados, y que una
  búsqueda repetida antes de un segundo recibe el estado degradado sin que la
  app se cierre.

## Self-review

- La spec cubre renderer, fuente de tiles, atribución, Nominatim, límites,
  contrato, capas dinámicas, privacidad y fallback.
- No se crean microservicios ni se modifica PostgreSQL; el gateway mantiene el
  límite entre proveedor y dominio.
- Los nombres de los campos coinciden: API `label`, Flutter `PlaceResult.name`
  como presentación, `location` en ambos y `dataState` requerido.
- La implementación no depende de Google ni incorpora secretos.
- La prueba de build iOS sustituye la simulación imposible de un PlatformView
  nativo en Flutter Test.
