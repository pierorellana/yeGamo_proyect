# yeGamo Integral Restructure Implementation Plan

> **For agentic workers:** Implement task-by-task with a verification checkpoint after every task. Preserve user worktree changes. Do not commit or push without explicit authorization.

**Goal:** Rebuild the Flutter App, NestJS API, persistence boundaries, visual system and SDD documentation so yeGamo implements the approved 17-screen prototype baseline and remains honest when no transport or geocoding provider exists.

**Architecture:** Keep `yegamo_app/` and `api/` as physical roots. Use modular Flutter features with shared services, repositories and `ChangeNotifier` providers; use a modular NestJS monolith with canonical HTTP DTOs, domain use cases, repositories, provider gateway and SQL-first persistence. Execute vertical slices so each slice has code, tests and documentation.

**Tech Stack:** Flutter/Dart, `provider` + `ChangeNotifier`, REST/JSON `/v1`, NestJS 11, TypeScript, PostgreSQL/PostGIS, Prisma Client for typed CRUD, SQL migrations, Jest/Supertest and Flutter widget/integration/golden tests.

## Global Constraints

- Preserve `yegamo_app/`, `api/` and `context/`; do not rename them to `App/` or `API`.
- `api/contracts/openapi.yaml` is the canonical HTTP contract.
- `api/db/migrations/` is the executable SQL source of truth.
- No authorized transit/geocoding provider exists; production must return canonical unavailable states.
- `DemoTransitProvider` and prototype fixtures are development/test-only and explicitly opt-in.
- `LIVE` requires an authorized source, recent timestamp and backend quality metadata.
- Do not persist precise location by default, store passwords or expose provider DTOs.
- Keep exactly 17 baseline screens and 9 reusable UX states; `arrived` and `nocov` remain states.
- Use `provider`/`ChangeNotifier`, named routes, `Navigator` and `IndexedStack` as specified.
- Update specs/ADR before functional implementation and update contract/examples/tests together.
- Preserve existing worktree changes and user-supplied prototype artifacts.
- Do not create commits, branches, pushes, provider accounts or credentials.
- End every task with `git diff --check` and its task-specific validator.

## Dependency Order

```
Task 1 docs/contract foundation
  -> Task 2 Flutter shared foundation       -> Task 5 App entry/discovery/planning
  -> Task 3 API provider gateway             -> Task 6 API identity/retention
  -> Task 4 API places/transit/journeys      -> Task 7 App journey/retention
                                             -> Task 8 integration/closeout
```

Tasks 2 and 3 may proceed independently after Task 1. Tasks 5 and 6 consume
the contract and gateway decisions. Task 8 is the release gate.

## Target File Map

- Documentation: `context/adr/ADR-008-providerless-mvp-and-prototype-fixtures.md`, `context/specs/*`, `context/architecture/*`, `context/plans/*`.
- Contract: `api/contracts/openapi.yaml`, `api/contracts/examples/*`.
- Flutter shared: `yegamo_app/lib/env/*`, `yegamo_app/lib/shared/*`, `yegamo_app/assets/*`.
- Flutter features: `yegamo_app/lib/modules/onboarding/`, `permissions/`, `home/`, `search/`, `nearby/`, `planner/`, `journey/`, `saved/`, `commutes/`, `notifications/`, `settings/`.
- API features: `api/src/identity/`, `places/`, `transit/`, `journeys/`, `active-journeys/`, `favorites/`, `commutes/`, `alerts/`, `notifications/`, `provider-gateway/`, `worker/`.
- Tests: `yegamo_app/test/**`, `yegamo_app/integration_test/**`, `api/test/**`.

---

### Task 1: Lock the approved design into specs, ADR and contract

**Files:**

- Create: `context/adr/ADR-008-providerless-mvp-and-prototype-fixtures.md`
- Modify: `context/specs/11_API_SPEC.md`, `12_OPENAPI.yaml`, `15_MOBILE_FLUTTER_SPEC.md`, `19_TESTING_ACCEPTANCE.md`, `CHANGELOG.md`
- Modify: `context/architecture/current-architecture.md`, `integration-boundaries.md`, `traceability.md`
- Modify: `api/contracts/openapi.yaml`, `api/contracts/examples/error.json`

**Interfaces:** Produces the canonical definitions for `UNAVAILABLE`,
`LOCATION_OUT_OF_COVERAGE`, demo-only provider mode, 17 screens, 9 states
and provider metadata rules. It does not rename public routes.

- [ ] Write ADR-008 with the providerless production decision, fixture gate,
  consequences for App/API/tests and future provider onboarding.
- [ ] Align API, Flutter and acceptance specs; explicitly classify `arrived`
  and `nocov` as states, not extra screens.
- [ ] Add missing provider-unavailable responses to place operations in the
  executable OpenAPI and retain `X-Trace-Id`.
- [ ] Update the derived spec copy, examples, traceability and changelog.
- [ ] Verify:

```bash
rg -n "RutaYa|Metrovia GTFS|LIVE|UNAVAILABLE|arrived|nocov" context api/contracts
git diff --check
```

Expected: every match is an explicit prototype/demo rule or canonical rule;
no production claim uses demo data.

---

### Task 2: Build Flutter shared foundation, tokens and assets

**Files:**

- Modify: `yegamo_app/pubspec.yaml`, `yegamo_app/lib/main.dart`
- Create: `yegamo_app/lib/env/config/app_config.dart`, `yegamo_app/lib/env/theme/yegamo_theme.dart`
- Create: `yegamo_app/lib/shared/models/data_state.dart`, `yegamo_app/lib/shared/models/api_error.dart`
- Create: `yegamo_app/lib/shared/services/api_client.dart`, `yegamo_app/lib/shared/services/connectivity_service.dart`
- Create: `yegamo_app/lib/shared/storage/local_storage.dart`, `yegamo_app/lib/shared/location/location_service.dart`
- Create: `yegamo_app/lib/shared/navigation/app_routes.dart`, `yegamo_app/lib/shared/navigation/app_navigator.dart`
- Create: `yegamo_app/lib/shared/design_system/yg_tokens.dart`, `yegamo_app/lib/shared/design_system/yg_components.dart`
- Create: `yegamo_app/lib/shared/widgets/remote_state_view.dart`, `yegamo_app/lib/shared/widgets/data_quality_badge.dart`
- Create tests under `yegamo_app/test/shared/`
- Add selected SVG/PNG assets from `yeGamo-prototipo-completo.zip` under `yegamo_app/assets/`

**Interfaces:**

```dart
enum DataState { current, stale, degraded, offlineCache, unavailable }
enum UxState { ok, loading, empty, error, offline, stale, degraded, permission, noCoverage }

abstract interface class HttpTransport {
  Future<TransportResponse> send(HttpRequest request);
}

class ApiClient {
  Future<ApiResponse<T>> get<T>(String path, {Map<String, String>? query});
  Future<ApiResponse<T>> post<T>(String path, {Object? body, String? idempotencyKey});
}
```

- [ ] Add current compatible dependencies for `provider`, HTTP, local
  preferences, secure storage, connectivity and location permissions.
- [ ] Implement immutable data/error models and map `503` details to
  `DataState.unavailable`.
- [ ] Implement injectable `HttpTransport`; add `/v1`, timeout, trace,
  bearer token and controlled safe-request retry in `ApiClient`.
- [ ] Translate approved tokens and create semantic, 44 px minimum shared
  controls for loading, empty, error, permission and quality states.
- [ ] Copy/register only required original assets; keep source ZIP/HTML intact.
- [ ] Add config for API URL, environment, explicit demo flag and reduce motion.
- [ ] Add named routes for all 17 screens and root `IndexedStack` navigation.
- [ ] Verify:

```bash
cd yegamo_app
flutter analyze
flutter test test/shared
git diff --check
```

Expected: analyzer and shared tests pass; no product screen depends on demo data.

---

### Task 3: Implement API provider gateway and unavailable semantics

**Files:**

- Modify: `api/src/provider-gateway/domain/provider.types.ts`, `api/src/provider-gateway/domain/provider.ports.ts`, `api/src/provider-gateway/domain/provider.errors.ts`
- Modify: `api/src/provider-gateway/application/transit-gateway.service.ts`
- Create: `api/src/provider-gateway/application/geocoding-gateway.service.ts`, `api/src/provider-gateway/application/provider-health.service.ts`
- Modify: `api/src/provider-gateway/mappers/transit-plan.mapper.ts`
- Modify: `api/src/provider-gateway/adapters/demo-transit.provider.ts`, `api/src/provider-gateway/provider-gateway.module.ts`
- Modify: `api/src/shared/errors/canonical-http-exception.filter.ts`, `api/src/app.module.ts`
- Create/modify: `api/test/provider-gateway/*.spec.ts`

**Interfaces:**

```ts
export interface GeocodingProvider {
  readonly providerKey: string;
  readonly isDemo: boolean;
  search(query: string, near?: GeoPoint): Promise<ProviderResult<unknown>>;
  reverse(point: GeoPoint): Promise<ProviderResult<unknown>>;
}

export interface ProviderAvailability {
  capability: 'transit' | 'geocoding' | 'vehicle-position' | 'incidents';
  status: 'HEALTHY' | 'DEGRADED' | 'UNAVAILABLE';
  provider: string | null;
}
```

- [ ] Write failing tests for no provider, timeout, invalid payload, demo
  mapping and configured non-demo provider with recent timestamp.
- [ ] Make gateway errors include capability, `dataState: 'UNAVAILABLE'`
  and retryability; preserve existing timeout behavior.
- [ ] Validate raw provider payloads at the boundary and map only canonical
  plans, places, quality and health models.
- [ ] Inject demo provider only when `NODE_ENV !== production` and an explicit
  demo flag is true; assert production resolves no demo provider.
- [ ] Ensure the global filter preserves canonical error fields and trace ID.
- [ ] Verify:

```bash
cd api
npm test -- --runInBand --watchman=false
npm run typecheck
npm run build
git diff --check
```

---

### Task 4: Implement API places, transit and journey planning

**Files:**

- Create: `api/src/places/places.module.ts`, `api/src/places/http/places.controller.ts`, `api/src/places/http/places.dto.ts`, `api/src/places/application/places.service.ts`, `api/src/places/domain/places.ports.ts`
- Create: `api/src/transit/transit.module.ts`, `api/src/transit/http/transit.controller.ts`, `api/src/transit/http/transit.dto.ts`, `api/src/transit/application/transit.service.ts`, `api/src/transit/domain/transit.ports.ts`
- Create: `api/src/journeys/journeys.module.ts`, `api/src/journeys/http/journeys.controller.ts`, `api/src/journeys/http/journeys.dto.ts`, `api/src/journeys/application/journeys.service.ts`, `api/src/journeys/domain/journeys.ports.ts`
- Modify: `api/src/app.module.ts`
- Create: `api/test/places/places.spec.ts`, `api/test/transit/transit.spec.ts`, `api/test/journeys/journeys.spec.ts`
- Create: `api/test/contracts/openapi-contract.spec.ts`

**Interfaces:**

```ts
export interface JourneysUseCase {
  plan(input: JourneyPlanRequest, context: RequestContext): Promise<TransitPlan>;
  get(planId: string, context: RequestContext): Promise<TransitPlan>;
}
```

- [ ] Test current OpenAPI paths for coordinate/radius/time validation, 503
  unavailable, 422 invalid input, 404 unknown resource and canonical success.
- [ ] Implement whitelist-compatible HTTP DTOs matching OpenAPI constraints.
- [ ] Implement places/transit use cases over gateway and repository ports;
  controllers must never receive raw adapter values.
- [ ] Implement plan validation, canonical preference ordering and plan
  persistence only where data policy allows it.
- [ ] Register modules and align request/response examples.
- [ ] Verify:

```bash
cd api
npm test -- --runInBand --watchman=false
npm run typecheck
npm run build
git diff --check
```

Expected: no-provider paths are tested recoverable responses and route names
match the canonical contract.

---

### Task 5: Implement Flutter entry, discovery and planning

**Files:**

- Create/modify: `yegamo_app/lib/modules/onboarding/`, `permissions/`, `home/`, `search/`, `nearby/`, `planner/`; each gets a page, ViewModel/provider, repository and feature models
- Create tests under `yegamo_app/test/modules/onboarding/`, `permissions/`, `home/`, `search/`, `nearby/`, `planner/`
- Create: `yegamo_app/integration_test/entry_to_planning_test.dart`

**Interfaces:**

```dart
class PlannerViewModel extends ChangeNotifier {
  PlannerViewModel({required JourneyRepository repository});
  PlannerState get state;
  Future<void> calculate();
  void cancel();
  void setTimeMode(TimeMode mode);
  void setPreference(TravelPreference preference);
}
```

- [ ] Test splash, onboarding swipe/next, permission allow/deny, manual
  origin, first-start persistence and fake location/storage.
- [ ] Implement entry pages with original assets, safe areas, named routes and
  reduced-motion branches.
- [ ] Implement Home repositories for nearby/favorites/notifications and map
  API errors to shared states.
- [ ] Implement Search and Nearby with recent local queries, manual origin,
  empty/no-coverage and quality badges.
- [ ] Implement Planner, Loading, Alternatives and Departure over
  `POST/GET /v1/journeys`; cancel without presenting a partial ETA.
- [ ] Translate sheet, toast, flip, progress and perspective effects with
  Flutter controllers; preserve a static functional transition under reduce motion.
- [ ] Verify:

```bash
cd yegamo_app
flutter analyze
flutter test
flutter test integration_test/entry_to_planning_test.dart
git diff --check
```

---

### Task 6: Implement API identity, persistence, active journeys and retention

**Files:**

- Create: `api/src/identity/identity.module.ts`, `api/src/favorites/favorites.module.ts`, `api/src/commutes/commutes.module.ts`, `api/src/alerts/alerts.module.ts`, `api/src/notifications/notifications.module.ts`, `api/src/active-journeys/active-journeys.module.ts`, `api/src/worker/worker.module.ts`
- Modify: `api/prisma/schema.prisma`
- Create: next sequential migration under `api/db/migrations/`
- Create tests under `api/test/identity/`, `favorites/`, `commutes/`, `alerts/`, `notifications/`, `active-journeys/`, `worker/`
- Modify: `api/test/database/migrations.e2e-spec.ts`

**Interfaces:**

```ts
export interface IdempotencyStore {
  get(principalId: string, key: string): Promise<StoredOperation | null>;
  put(operation: StoredOperation): Promise<void>;
}
```

- [ ] Compare current SQL migrations and Prisma models before adding tables;
  apply the new migration from empty and current schemas.
- [ ] Implement JWT/OIDC principal boundary; protected routes return 401/403
  and no password-auth system is added.
- [ ] Implement repositories returning domain models, with Prisma for CRUD and
  explicit PostGIS SQL only where justified.
- [ ] Implement active journey transitions and idempotent start/progress/
  finish/cancel, including location consent.
- [ ] Implement favorites, commutes, alerts and notification read state with
  ownership and `Idempotency-Key`.
- [ ] Implement deterministic worker ports for alerts, delivery, retention and
  provider health; keep workers disabled unless explicitly invoked in tests.
- [ ] Verify:

```bash
cd api
npm run db:verify
npm test -- --runInBand --watchman=false
npm run typecheck
npm run build
git diff --check
```

---

### Task 7: Implement Flutter journey, retention and privacy

**Files:**

- Create/modify: `yegamo_app/lib/modules/journey/`, `saved/`, `commutes/`, `notifications/`, `settings/`; each gets a page, ViewModel/provider, repository and feature models
- Modify: `yegamo_app/lib/shared/session/`, `yegamo_app/lib/shared/storage/`, `yegamo_app/lib/shared/location/`
- Create tests under `yegamo_app/test/modules/journey/`, `saved/`, `commutes/`, `notifications/`, `settings/`
- Create: `yegamo_app/integration_test/active_journey_and_retention_test.dart`

**Interfaces:**

```dart
class JourneyViewModel extends ChangeNotifier {
  JourneyViewModel({required ActiveJourneyRepository repository});
  JourneyState get state;
  Future<void> start(String planId, String optionId);
  Future<void> updateProgress(JourneyProgress progress);
  Future<void> finish();
  Future<void> cancel();
}
```

- [ ] Test step-by-step, active, get-off, arrived, stale/degraded ETA, offline
  cache, permission required, finish and cancel confirmation.
- [ ] Render canonical legs, transfers, progress and quality badges with
  prototype motion and providerless map honesty.
- [ ] Implement saved places, empty state, fake local guest storage and
  explicit guest-to-account sync without unconsented precise location.
- [ ] Implement routines, confirmed suggestions, pause/resume and timezone-safe
  leave alerts.
- [ ] Implement notifications, settings, privacy, export/delete and the
  development-only demo-state catalog.
- [ ] Verify:

```bash
cd yegamo_app
flutter analyze
flutter test
flutter test integration_test/active_journey_and_retention_test.dart
git diff --check
```

---

### Task 8: Golden tests, contract validation and closeout

**Files:**

- Create: `yegamo_app/test/fixtures/prototype_states.dart`, `test/goldens/*`
- Create: `yegamo_app/integration_test/full_baseline_flow_test.dart`
- Modify: `context/architecture/traceability.md`, `context/plans/FOUNDATIONS-CLOSEOUT.md`
- Create: `context/plans/RESTRUCTURE-CLOSEOUT.md`
- Modify: `context/specs/CHANGELOG.md`, `yegamo_app/README.md`, `api/README.md`, `api/contracts/README.md`
- Modify: `api/test/contracts/openapi-contract.spec.ts`

**Interfaces:** The fixture catalog is test-only and names all 17 screens and
9 states. The closeout matrix maps every RF group to module, endpoint,
migration and test.

- [ ] Create deterministic fixtures with fake clock/transport for all UX states.
- [ ] Add goldens at the 393×852 reference size and a wider constraint for
  safe areas, text wrapping, sheets, tabs, badges and reduced motion.
- [ ] Exercise the full first-launch → journey → retention flow with fake API
  and no-provider configuration.
- [ ] Validate every published OpenAPI operation, field, status, header,
  example and canonical error against controllers.
- [ ] Update architecture, traceability, README setup, demo-mode instructions
  and verified closeout status.
- [ ] Run:

```bash
cd yegamo_app && flutter analyze && flutter test
cd ../api && npm run typecheck && npm run build && npm test -- --runInBand --watchman=false
cd .. && git diff --check
```

- [ ] Run `cd api && npm run db:verify` and migration e2e when a database is
  available; record unavailable prerequisites instead of fabricating a pass.
- [ ] Final safety review:

```bash
rg -n "password|secret|api[_-]?key|RutaYa|Metrovia GTFS|LIVE|providerDisplayName" yegamo_app api context
git status --short
git diff --check
```

Review each match for secrets, obsolete branding, unauthorized provider
claims and demo leakage. Preserve user-added untracked artifacts.

## Verification Matrix

| Requirement | Implementation | Verification |
|---|---|---|
| 17 screens | `yegamo_app/lib/modules/**` | integration + golden catalog |
| 9 UX states | shared state widgets | state/widget tests |
| Honest data | provider gateway and `DataQuality` | no-provider e2e + mapper tests |
| API boundary | OpenAPI + controllers | contract suite |
| No provider | config + gateway errors | production configuration test |
| Privacy | location/session/settings | widget + authorization tests |
| SQL source of truth | `api/db/migrations/` | migration e2e + `db:verify` |
| Prototype fidelity | tokens/assets/motion | golden tests + reference review |
| Accessibility | Semantics/reduce motion/targets | widget semantics tests |

## Self-Review

- Coverage: Tasks 1–8 cover the approved architecture, visual baseline,
  providerless behavior, API/persistence boundaries, vertical implementation,
  testing and documentation closeout.
- Completeness scan: no unresolved placeholder or unspecified provider/secret
  step is required; paths, interfaces and commands are explicit.
- Type consistency: App tasks use `ApiClient`, `PlannerViewModel` and
  `JourneyViewModel`; API tasks use gateway/repository ports and canonical
  `JourneyPlanRequest`/`TransitPlan`.
- Scope: the broad request is split into eight independently verifiable tasks.
- Safety: no task authorizes commits, pushes, credentials, destructive cleanup,
  provider acquisition or root-directory renames.
