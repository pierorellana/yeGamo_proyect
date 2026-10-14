# OSM Real Data MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use the checkbox syntax - [ ] for tracking.

**Goal:** Mostrar lugares y paradas reales de OpenStreetMap en el MVP mediante un gateway NestJS con caché e importación idempotente, sin ETA, horarios ni datos simulados.

**Architecture:** Flutter continuará consumiendo los contratos HTTP existentes. El API consultará PostgreSQL/PostGIS primero y utilizará Nominatim para lugares y Overpass para descubrir paradas únicamente cuando falten datos locales. Las respuestas externas se normalizarán dentro del gateway y las paradas OSM se persistirán usando las tablas existentes transit_stops y provider_references.

**Tech Stack:** NestJS 11, TypeScript, PostgreSQL/PostGIS, PrismaService con SQL parametrizado, Jest/Supertest, Flutter/Dart, Provider, MapLibre GL.

## Global Constraints

- No usar datos demo como producción ni crear ETA, horarios, rutas o posiciones de buses sintéticas.
- CURRENT y LIVE no se usarán para paradas OSM; las paradas OSM se devolverán como DEGRADED.
- No exponer DTOs de Nominatim u Overpass en el contrato HTTP.
- Mantener api/contracts/openapi.yaml como contrato canónico.
- No agregar una migración: transit_stops y provider_references ya soportan la persistencia necesaria.
- Mantener Nominatim y Overpass detrás del API; Flutter no llamará servicios OSM directamente.
- Respetar caché, User-Agent, atribución y límites de los servicios públicos de OpenStreetMap.
- No persistir la ubicación precisa del usuario; solo se persistirán las coordenadas de las paradas externas.
- Ejecutar pruebas automatizadas y git diff --check antes de cada cierre.

---

### Task 1: Expandir el contrato de proveedores y la configuración OSM

**Files:**
- Modify: api/src/provider-gateway/domain/provider.ports.ts
- Modify: api/src/provider-gateway/provider-gateway.module.ts
- Modify: api/src/config/configuration.ts
- Modify: api/.env.example
- Test: api/test/provider-gateway/provider-gateway.spec.ts

**Interfaces:**
- Produces TransitStopCandidate, TransitStopDiscoveryInput, TransitStopDiscoveryProvider, TRANSIT_STOP_DISCOVERY_PROVIDERS y TransitStopDiscoveryGatewayService.
- TransitStopCandidate contiene únicamente externalId, name y location; ningún tag crudo de Overpass cruza el límite del proveedor.

- [ ] **Step 1: Write the failing provider contract test**

Add a test that compiles a fake discovery provider and verifies that the discovery gateway returns only canonical candidates:

~~~ts
it('returns canonical candidates from the configured stop provider', async () => {
  const gateway = new TransitStopDiscoveryGatewayService([
    {
      providerKey: 'openstreetmap-overpass',
      isDemo: false,
      discoverStops: async () => ({
        providerKey: 'openstreetmap-overpass',
        isDemo: false,
        sourceAuthorized: true,
        observedAt: '2026-10-14T12:00:00.000Z',
        data: [{
          externalId: 'node:123',
          name: 'Parada Centro',
          location: { lat: -2.17, lon: -79.9 },
        }],
      }),
    },
  ]);

  await expect(
    gateway.discover({ lat: -2.17, lon: -79.9, radiusM: 800 }),
  ).resolves.toEqual({
    providerKey: 'openstreetmap-overpass',
    sourceAuthorized: true,
    observedAt: '2026-10-14T12:00:00.000Z',
    stops: [{
      externalId: 'node:123',
      name: 'Parada Centro',
      location: { lat: -2.17, lon: -79.9 },
    }],
  });
});
~~~

Run: cd api && npm test -- --runInBand provider-gateway.spec.ts
Expected: FAIL because the discovery contract and gateway do not exist.

- [ ] **Step 2: Add the canonical discovery interfaces and gateway**

Add these interfaces to api/src/provider-gateway/domain/provider.ports.ts:

~~~ts
export interface TransitStopCandidate {
  externalId: string;
  name: string;
  location: GeoPoint;
}

export interface TransitStopDiscoveryInput {
  lat: number;
  lon: number;
  radiusM: number;
}

export interface TransitStopDiscoveryProvider {
  readonly providerKey: string;
  readonly isDemo: boolean;
  discoverStops(
    input: TransitStopDiscoveryInput,
  ): Promise<ProviderResult<TransitStopCandidate[]>>;
}
~~~

Create api/src/provider-gateway/application/transit-stop-discovery-gateway.service.ts. It must expose TRANSIT_STOP_DISCOVERY_PROVIDERS and a discover method that:

~~~ts
export interface TransitStopDiscoveryResult {
  providerKey: string;
  sourceAuthorized: boolean;
  observedAt: string | null;
  stops: TransitStopCandidate[];
}

async discover(
  input: TransitStopDiscoveryInput,
  timeoutMs = 10000,
): Promise<TransitStopDiscoveryResult>
~~~

Use the same timeout and error normalization rules as GeocodingGatewayService. Validate every candidate before returning it.

- [ ] **Step 3: Register the empty/default provider list and configuration**

Extend AppConfiguration and configuration() with overpassEnabled, overpassBaseUrl, overpassTimeoutMs and overpassCacheTtlMs. Defaults must be:

~~~ts
overpassEnabled: process.env.OVERPASS_ENABLED === 'true',
overpassBaseUrl: process.env.OVERPASS_BASE_URL
  ?? 'https://overpass-api.de/api/interpreter',
overpassTimeoutMs: Number.parseInt(process.env.OVERPASS_TIMEOUT_MS ?? '10000', 10),
overpassCacheTtlMs: Number.parseInt(process.env.OVERPASS_CACHE_TTL_MS ?? '900000', 10),
~~~

Register TransitStopDiscoveryGatewayService and its provider token in ProviderGatewayModule. The factory must enable Overpass only when OVERPASS_ENABLED=true and must default to an empty list under NODE_ENV=test or NODE_ENV=production.

Append to api/.env.example:

~~~dotenv
OVERPASS_ENABLED=true
OVERPASS_BASE_URL=https://overpass-api.de/api/interpreter
OVERPASS_TIMEOUT_MS=10000
OVERPASS_CACHE_TTL_MS=900000
~~~

- [ ] **Step 4: Run the focused contract tests**

Run: cd api && npm test -- --runInBand provider-gateway.spec.ts
Expected: PASS, with existing provider gateway behavior unchanged.

- [ ] **Step 5: Commit the contract/configuration task**

~~~bash
git add api/src/provider-gateway api/src/config api/.env.example api/test/provider-gateway/provider-gateway.spec.ts
git commit -m "feat(api): add transit stop discovery gateway"
~~~

### Task 2: Implement the Overpass stop provider with bounded queries and cache

**Files:**
- Create: api/src/provider-gateway/adapters/overpass-transit.provider.ts
- Create: api/test/provider-gateway/overpass-transit.provider.spec.ts
- Modify: api/src/provider-gateway/provider-gateway.module.ts

**Interfaces:**
- Consumes TransitStopDiscoveryInput.
- Produces ProviderResult<TransitStopCandidate[]> with providerKey openstreetmap-overpass, isDemo false, sourceAuthorized true and an observed timestamp.

- [ ] **Step 1: Write parser and cache tests**

Cover valid nodes, all three accepted stop tags, missing names, invalid coordinates, malformed JSON, cache reuse and request pacing:

~~~ts
it('maps valid OSM stop nodes and ignores invalid coordinates', async () => {
  const fetcher = jest.fn(async () => new Response(JSON.stringify({
    elements: [
      { type: 'node', id: 10, lat: -2.17, lon: -79.9,
        tags: { highway: 'bus_stop', name: 'Centro' } },
      { type: 'node', id: 11, lat: 99, lon: -79.9,
        tags: { public_transport: 'platform' } },
    ],
  }), { status: 200 })) as unknown as typeof fetch;

  const provider = new OpenStreetMapTransitProvider({
    baseUrl: 'https://overpass.test/api/interpreter',
    fetcher,
    now: () => new Date('2026-10-14T12:00:00.000Z'),
    cacheTtlMs: 900000,
  });

  await expect(provider.discoverStops({
    lat: -2.17,
    lon: -79.9,
    radiusM: 800,
  })).resolves.toMatchObject({
    providerKey: 'openstreetmap-overpass',
    sourceAuthorized: true,
    data: [{
      externalId: 'node:10',
      name: 'Centro',
      location: { lat: -2.17, lon: -79.9 },
    }],
  });
});

it('serves the same cell from cache without a second HTTP request', async () => {
  const fetcher = jest.fn(async () => new Response(
    JSON.stringify({ elements: [] }),
    { status: 200 },
  )) as unknown as typeof fetch;
  const provider = new OpenStreetMapTransitProvider({
    fetcher,
    now: () => new Date('2026-10-14T12:00:00.000Z'),
    cacheTtlMs: 900000,
  });

  const input = { lat: -2.17, lon: -79.9, radiusM: 800 };
  await provider.discoverStops(input);
  await provider.discoverStops(input);

  expect(fetcher).toHaveBeenCalledTimes(1);
});
~~~

Run: cd api && npm test -- --runInBand overpass-transit.provider.spec.ts
Expected: FAIL because the adapter does not exist.

- [ ] **Step 2: Implement bounded Overpass request construction**

Create the provider with injectable fetcher, now, baseUrl, cacheTtlMs and minRequestIntervalMs. Convert the radius to a latitude/longitude bounding box, clamp coordinates to valid ranges, and build this query:

~~~overpassql
[out:json][timeout:10];
(
  node["highway"="bus_stop"](south,west,north,east);
  node["public_transport"="platform"](south,west,north,east);
  node["public_transport"="stop_position"](south,west,north,east);
);
out body;
~~~

POST data=encoded-query-body to the configured endpoint with Accept: application/json and User-Agent: yeGamo-local-dev/1.0 (contacto técnico yeGamo). Parse only elements[] nodes, deduplicate by node:osm-id, prefer tags.name, then tags.local_ref, then Parada sin nombre, and reject non-finite coordinates.

- [ ] **Step 3: Implement TTL and request pacing**

Cache successful candidate arrays by a rounded geographic cell plus radius. Use a fifteen-minute default TTL. Before an uncached request, wait until at least one second has elapsed since the last external request; do not issue concurrent uncached requests for the same cell. Return ProviderGatewayError(PROVIDER_UNAVAILABLE) for network errors, HTTP 429/5xx, timeout or invalid JSON.

- [ ] **Step 4: Register the configured adapter**

Instantiate OpenStreetMapTransitProvider in the provider factory using OVERPASS_BASE_URL, OVERPASS_TIMEOUT_MS, OVERPASS_CACHE_TTL_MS and NOMINATIM_USER_AGENT. Do not register it when the environment is test/production without explicit OVERPASS_ENABLED=true.

- [ ] **Step 5: Run adapter tests and commit**

Run: cd api && npm test -- --runInBand overpass-transit.provider.spec.ts
Expected: PASS.

~~~bash
git add api/src/provider-gateway/adapters/overpass-transit.provider.ts api/src/provider-gateway/provider-gateway.module.ts api/test/provider-gateway/overpass-transit.provider.spec.ts
git commit -m "feat(api): discover osm transit stops through overpass"
~~~

### Task 3: Persist OSM stops idempotently and expose their source

**Files:**
- Modify: api/src/transit/domain/transit.ports.ts
- Modify: api/src/transit/infrastructure/prisma-transit.repository.ts
- Modify: api/src/transit/transit.module.ts
- Modify: api/contracts/openapi.yaml
- Modify: api/test/transit/transit-repository.e2e-spec.ts

**Interfaces:**
- Produces TRANSIT_CATALOG_WRITE_PORT and TransitCatalogWritePort.upsertDiscoveredStops().
- Extends TransitStop with source: string | null.
- Does not add or alter a database migration.

- [ ] **Step 1: Add the failing contract/repository assertions**

Update the canonical success test to include source: null for an unreferenced fixture stop, and add a database-backed assertion for an OSM provider reference:

~~~ts
expect(stops[0]).toMatchObject({
  source: null,
});

await repository.upsertDiscoveredStops([{
  externalId: 'node:9001',
  name: 'Parada OSM',
  location: { lat: -2.17, lon: -79.9 },
  provider: 'openstreetmap',
}]);

await expect(repository.nearbyStops({
  lat: -2.17,
  lon: -79.9,
  radiusM: 100,
})).resolves.toEqual(expect.arrayContaining([
  expect.objectContaining({
    name: 'Parada OSM',
    source: 'openstreetmap',
    dataState: 'DEGRADED',
  }),
]));
~~~

Run: cd api && npm run test:e2e -- --runInBand transit-repository.e2e-spec.ts
Expected: FAIL or skip without DATABASE_URL; with the database, it fails until the write path exists.

- [ ] **Step 2: Add the catalog write port**

Add to transit.ports.ts:

~~~ts
export interface DiscoveredTransitStop {
  externalId: string;
  provider: string;
  name: string;
  location: GeoPoint;
}

export const TRANSIT_CATALOG_WRITE_PORT = Symbol('TRANSIT_CATALOG_WRITE_PORT');

export interface TransitCatalogWritePort {
  upsertDiscoveredStops(stops: DiscoveredTransitStop[]): Promise<void>;
}
~~~

Change TransitStop to include source: string | null.

- [ ] **Step 3: Add source mapping to the local read query**

In PrismaTransitReadRepository.nearbyStops, add a lateral join over provider_references for entity_type = STOP, select the most recently updated provider, and map source: row.source. Leave dataState: DEGRADED for every catalog stop until an authorized transit feed exists.

- [ ] **Step 4: Implement the idempotent transaction**

Add upsertDiscoveredStops using prisma.$transaction. For each candidate:

~~~text
find provider_references(provider, entity_type STOP, external_id)
if found:
  update transit_stops(id, name, location, updated_at)
  update provider_references(last_seen_at, updated_at)
if not found:
  insert transit_stops(name, location, canonical_status ACTIVE)
  insert provider_references(entity_type STOP, entity_id, provider, external_id,
                             storage_policy PERSIST_ALLOWED, last_seen_at)
  on duplicate provider reference, re-read its entity_id and update that stop
~~~

Use parameterized SQL through Prisma.sql; never interpolate candidate names or identifiers. Keep the provider reference unique key as the duplicate guard.

- [ ] **Step 5: Bind the write port and update OpenAPI**

Register:

~~~ts
{
  provide: TRANSIT_CATALOG_WRITE_PORT,
  useExisting: PrismaTransitReadRepository,
}
~~~

Add the nullable source property to components.schemas.TransitStop in api/contracts/openapi.yaml.

- [ ] **Step 6: Run repository and contract tests**

Run: cd api && npm test -- --runInBand transit.spec.ts
Expected: PASS.

Run: cd api && npm run test:e2e -- --runInBand transit-repository.e2e-spec.ts
Expected: PASS with DATABASE_URL; skip without it.

- [ ] **Step 7: Commit the persistence task**

~~~bash
git add api/src/transit api/contracts/openapi.yaml api/test/transit
git commit -m "feat(api): persist osm transit stops with source metadata"
~~~

### Task 4: Add local-first discovery orchestration to the transit endpoint

**Files:**
- Modify: api/src/transit/application/transit.service.ts
- Modify: api/src/transit/transit.module.ts
- Modify: api/test/transit/transit.spec.ts

**Interfaces:**
- Consumes TransitReadPort, TransitCatalogWritePort and TransitStopDiscoveryGatewayService.
- Keeps GET /v1/transit/stops/nearby unchanged.

- [ ] **Step 1: Write local-first behavior tests**

Add tests with fake ports:

~~~ts
it('does not call discovery when local stops exist', async () => {
  const discovery = { discover: jest.fn() };
  const read = {
    nearbyStops: jest.fn(async () => [{
      id: '550e8400-e29b-41d4-a716-446655440001',
      name: 'Parada local',
      location: { lat: -2.17, lon: -79.9 },
      distanceM: 100,
      dataState: 'DEGRADED',
      source: 'openstreetmap',
    }],
    departures: async () => [],
    route: async () => null,
  };
  const service = new TransitService(read, discovery, {
    upsertDiscoveredStops: jest.fn(),
  });

  await service.nearbyStops({ lat: -2.17, lon: -79.9, radiusM: 800 });

  expect(discovery.discover).not.toHaveBeenCalled();
});

it('discovers, persists and reads again when local stops are empty', async () => {
  const read = {
    nearbyStops: jest.fn()
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([{
        id: '550e8400-e29b-41d4-a716-446655440002',
        name: 'Parada OSM',
        location: { lat: -2.17, lon: -79.9 },
        distanceM: 120,
        dataState: 'DEGRADED',
        source: 'openstreetmap',
      }]),
    departures: async () => [],
    route: async () => null,
  };
  const discovery = {
    discover: jest.fn(async () => ({
      providerKey: 'openstreetmap-overpass',
      sourceAuthorized: true,
      observedAt: '2026-10-14T12:00:00.000Z',
      stops: [{
        externalId: 'node:10',
        name: 'Parada OSM',
        location: { lat: -2.17, lon: -79.9 },
      }],
    })),
  };
  const write = { upsertDiscoveredStops: jest.fn(async () => undefined) };
  const service = new TransitService(read, discovery, write);

  await expect(service.nearbyStops({
    lat: -2.17,
    lon: -79.9,
    radiusM: 800,
  })).resolves.toHaveLength(1);
  expect(write.upsertDiscoveredStops).toHaveBeenCalledWith([{
    externalId: 'node:10',
    provider: 'openstreetmap',
    name: 'Parada OSM',
    location: { lat: -2.17, lon: -79.9 },
  }]);
});
~~~

Run: cd api && npm test -- --runInBand transit.spec.ts
Expected: FAIL until the service accepts the new ports.

- [ ] **Step 2: Implement fallback orchestration**

Change TransitService.nearbyStops to:

~~~ts
const local = await this.read.nearbyStops(input);
if (local.length > 0) return local;

try {
  const discovered = await this.discovery.discover(input);
  if (discovered.stops.length > 0) {
    await this.catalog.upsertDiscoveredStops(
      discovered.stops.map((stop) => ({
        ...stop,
        provider: discovered.providerKey === 'openstreetmap-overpass'
          ? 'openstreetmap'
          : discovered.providerKey,
      })),
    );
    return this.read.nearbyStops(input);
  }
} catch (error) {
  if (!(error instanceof ProviderGatewayError)) throw error;
}

return local;
~~~

The endpoint returns an empty successful array when there is no local coverage and the discovery provider is unavailable; it still propagates a database/provider read failure through the existing canonical 503 filter.

- [ ] **Step 3: Inject dependencies and preserve route/departure behavior**

Inject TRANSIT_READ_PORT, TransitStopDiscoveryGatewayService and TRANSIT_CATALOG_WRITE_PORT into TransitService. Update TransitModule to import ProviderGatewayModule, bind both TRANSIT_READ_PORT and TRANSIT_CATALOG_WRITE_PORT with useExisting: PrismaTransitReadRepository, and export the write binding without changing departures or route.

- [ ] **Step 4: Run HTTP tests**

Run: cd api && npm test -- --runInBand transit.spec.ts
Expected: PASS, including existing 422, 503, 404 and canonical response tests.

- [ ] **Step 5: Commit the orchestration task**

~~~bash
git add api/src/transit/application/transit.service.ts api/src/transit/transit.module.ts api/test/transit/transit.spec.ts
git commit -m "feat(api): discover transit stops on local coverage miss"
~~~

### Task 5: Add source metadata and debounced real search to Flutter

**Files:**
- Modify: yegamo_app/lib/modules/nearby/models/nearby_models.dart
- Modify: yegamo_app/lib/modules/nearby/pages/nearby_page.dart
- Modify: yegamo_app/lib/modules/nearby/widgets/nearby_widgets.dart
- Modify: yegamo_app/lib/modules/home/widgets/home_widgets.dart
- Modify: yegamo_app/lib/modules/search/widgets/search_widgets.dart
- Modify: yegamo_app/lib/modules/search/pages/search_page.dart
- Test: yegamo_app/test/modules/nearby/nearby_test.dart
- Test: yegamo_app/test/modules/search/search_page_test.dart

**Interfaces:**
- NearbyStop.source is nullable and parses source from the API.
- SearchOriginDestination.onChanged is optional and receives the text value.
- SearchPage owns a Timer and calls the existing SearchViewModel.search only after 500 ms and at least three characters.

- [ ] **Step 1: Add model and widget tests**

Add:

~~~dart
test('parses source metadata from an OSM nearby stop', () {
  final stop = NearbyStop.fromJson({
    'id': 'stop-1',
    'name': 'Parada OSM',
    'distanceM': 120,
    'source': 'openstreetmap',
    'dataState': 'DEGRADED',
    'location': {'lat': -2.17, 'lon': -79.9},
  });

  expect(stop.source, 'openstreetmap');
  expect(stop.dataState, DataState.degraded);
});
~~~

Add a widget test that enters term, waits 500 ms and verifies one repository search call; entering one or two characters must not search.

Run: cd yegamo_app && fvm flutter test test/modules/nearby/nearby_test.dart test/modules/search/search_page_test.dart
Expected: FAIL until the model, callback and timer exist.

- [ ] **Step 2: Extend nearby source parsing and labels**

Add String? source to NearbyStop and parse json['source'] as String?. Add:

~~~dart
String nearbySourceLabel(NearbyStop stop) =>
    stop.source == 'openstreetmap'
        ? 'OpenStreetMap'
        : 'Fuente no especificada';
~~~

Show the label below the distance in NearbyStopCard and HomeNearCard while retaining YgFreshnessLabel(stop.dataState).

- [ ] **Step 3: Add debounced search input**

Add ValueChanged<String>? onChanged to SearchOriginDestination and pass it to TextField.onChanged. In SearchPage add:

~~~dart
Timer? _searchDebounce;

void _onQueryChanged(String value) {
  _searchDebounce?.cancel();
  final trimmed = value.trim();
  final vm = context.read<SearchViewModel>();
  vm.setQuery(value);
  if (trimmed.length < 3) {
    vm.loadRecents();
    setState(() => _searched = null);
    return;
  }
  _searchDebounce = Timer(const Duration(milliseconds: 500), () {
    if (!mounted) return;
    _search();
  });
}
~~~

Cancel the timer in dispose, pass onChanged: _onQueryChanged and make _search return without an API call for fewer than three characters. Keep submit behavior by cancelling the timer before executing the immediate search.

- [ ] **Step 4: Improve nearby state copy**

Change the empty/degraded copy to explain that OSM provides locations only:

~~~text
Sin paradas mapeadas cerca de ti
No encontramos paradas de transporte en OpenStreetMap dentro del radio seleccionado.
~~~

Use Datos limitados for OSM and do not mention buses, ETA or live positions as if they were available.

- [ ] **Step 5: Run Flutter tests and commit**

Run: cd yegamo_app && fvm flutter test test/modules/nearby/nearby_test.dart test/modules/search/search_page_test.dart
Expected: PASS.

~~~bash
git add yegamo_app/lib/modules/nearby yegamo_app/lib/modules/home/widgets/home_widgets.dart yegamo_app/lib/modules/search yegamo_app/test/modules/nearby/nearby_test.dart yegamo_app/test/modules/search/search_page_test.dart
git commit -m "feat(app): show osm sources and debounce place search"
~~~

### Task 6: Center the real map on selected places and keep attribution visible

**Files:**
- Modify: yegamo_app/lib/shared/map/yg_map_view.dart
- Modify: yegamo_app/lib/shared/map/yg_map_host.dart
- Modify: yegamo_app/lib/shared/map/yg_real_map.dart
- Modify: yegamo_app/lib/modules/search/pages/search_page.dart
- Test: yegamo_app/test/shared/map/yg_map_test.dart

**Interfaces:**
- YgMapScope.focusOn(GeoCoordinate point) creates a one-shot camera request.
- YgRealMap receives the request and animates the MapLibre camera.
- Existing map points and OSM attribution remain unchanged.

- [ ] **Step 1: Write the camera request test**

Add:

~~~dart
test('focusOn publishes a new camera target', () {
  final scope = YgMapScope();
  final point = const GeoCoordinate(latitude: -2.17, longitude: -79.9);

  scope.focusOn(point);

  expect(scope.focusTarget?.latitude, point.latitude);
  expect(scope.focusTarget?.longitude, point.longitude);
  expect(scope.focusRequestVersion, 1);
});
~~~

Run: cd yegamo_app && fvm flutter test test/shared/map/yg_map_test.dart
Expected: FAIL until the scope exposes the request.

- [ ] **Step 2: Implement one-shot focus propagation**

Add GeoCoordinate? focusTarget and an incrementing focusRequestVersion to YgMapScope. Pass both through YgMapHost to YgRealMap. In YgRealMap.didUpdateWidget, when the version changes and the target is valid, call:

~~~dart
controller.animateCamera(
  CameraUpdate.newLatLngZoom(
    LatLng(target.latitude, target.longitude),
    15,
  ),
);
~~~

In the search result onTap, call context.read<YgMapScope>().focusOn(GeoCoordinate(latitude: result.latitude, longitude: result.longitude)) before navigating to the planner.

- [ ] **Step 3: Verify map attribution and marker sources**

Keep © OpenStreetMap contributors visible for the fallback raster style. Verify that GeoJSON marker properties continue to carry the API dataState, and that search places and nearby stops both remain rendered by YgMapHost.

- [ ] **Step 4: Run map tests and commit**

Run: cd yegamo_app && fvm flutter test test/shared/map/yg_map_test.dart
Expected: PASS.

~~~bash
git add yegamo_app/lib/shared/map yegamo_app/lib/modules/search/pages/search_page.dart yegamo_app/test/shared/map/yg_map_test.dart
git commit -m "feat(app): focus real map on selected places"
~~~

### Task 7: Document local execution and run the complete verification

**Files:**
- Modify: api/README.md
- Modify: yegamo_app/README.md
- Modify: docs/superpowers/specs/2026-10-14-osm-mvp-real-data-design.md only if implementation deviates from the approved design
- Test: api/test/contracts/openapi-contract.spec.ts

**Interfaces:**
- Produces a reproducible local command for the API, tunnel and Flutter device.
- Does not add secrets, credentials or generated artifacts.

- [ ] **Step 1: Document development configuration**

Add to api/README.md:

~~~bash
NODE_ENV=development \
OVERPASS_ENABLED=true \
NOMINATIM_ENABLED=true \
NOMINATIM_USER_AGENT='yeGamo-local-dev/1.0 (contacto del desarrollador)' \
npm run start:dev
~~~

Document that OSM results are real geographic data with DEGRADED status and that ETA/live data is intentionally unavailable in this MVP phase. Add the Flutter command with --dart-define=YEGAMO_REAL_MAP=true and the current HTTPS tunnel URL supplied at execution time, without committing that URL.

- [ ] **Step 2: Verify the OpenAPI contract**

Run: cd api && npm test -- --runInBand contracts/openapi-contract.spec.ts
Expected: PASS and the TransitStop.source property is present in the canonical contract.

- [ ] **Step 3: Run API verification**

Run: cd api && npm run typecheck
Expected: PASS.

Run: cd api && npm test -- --runInBand
Expected: PASS; database e2e suites skip only when DATABASE_URL is absent.

- [ ] **Step 4: Run Flutter verification**

Run: cd yegamo_app && fvm flutter analyze
Expected: No analyzer errors.

Run: cd yegamo_app && fvm flutter test
Expected: PASS.

- [ ] **Step 5: Validate formatting and diff hygiene**

Run: cd /Users/jorge/Desktop/yeGamo && git diff --check
Expected: no output.

Run: cd /Users/jorge/Desktop/yeGamo && git status --short
Expected: only intentional source/docs changes; existing .claude/, .fvm/ and generated SwiftPM files remain untracked and are not added.

- [ ] **Step 6: Commit documentation and final verification**

~~~bash
git add api/README.md yegamo_app/README.md
git commit -m "docs: document osm mvp runtime configuration"
~~~

Run: git log --oneline -7
Expected: implementation commits appear separately, with no push performed by this plan.
