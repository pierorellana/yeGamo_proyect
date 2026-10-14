# yeGamo Map, Planner and Keyboard Interaction Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute this plan inline with verification checkpoints. Do not create commits unless the user explicitly requests them.

**Goal:** Make the real MapLibre map interactive and data-bearing, let users plan with real place searches instead of coordinates, and keep every sheet usable while the keyboard is open.

**Architecture:** Keep `YgMapHost` as the boundary between Flutter screens and MapLibre. Extend the existing map controller with an optional native camera bridge, and keep provider failures honest while making the Overpass gateway more resilient. Reuse the existing canonical `/v1/places/search` path for planner address selection and keep journey requests coordinate-based only at the API boundary.

**Tech Stack:** Flutter/Dart, `maplibre_gl` 0.27.1, Provider, NestJS/TypeScript, PostgreSQL/PostGIS, Nominatim and Overpass through the provider gateway.

## Global Constraints

- No demo data in normal production execution.
- No invented ETA and no `LIVE` state without an authorized source and timestamp.
- Do not persist the user's precise location.
- Do not expose provider DTOs outside the provider gateway.
- Do not commit or push in this execution.
- Preserve the existing OpenStreetMap attribution.

---

### Task 1: MapLibre gestures and native camera controls

**Files:**
- Modify: `yegamo_app/lib/shared/map/yg_map_view.dart`
- Modify: `yegamo_app/lib/shared/map/yg_map_host.dart`
- Modify: `yegamo_app/lib/shared/map/yg_real_map.dart`
- Modify: `yegamo_app/lib/shared/map/yg_map_controls.dart` only if the controller API requires a semantic label update
- Test: `yegamo_app/test/shared/map/yg_map_test.dart`

**Interfaces:**
- `YgMapController.attachNativeCamera({required Future<void> Function(double) zoomBy, required Future<void> Function() reset, required Future<void> Function(Offset) panTo})` binds MapLibre commands.
- `YgMapController.detachNativeCamera()` removes the binding without affecting fake-map tests.
- `YgRealMap` receives the shared `YgMapController` and binds it after creation.

- [ ] Add controller bridge callbacks while retaining fake zoom/pan state for existing tests.
- [ ] Pass the shared controller from `YgMapHost` into `YgRealMap`.
- [ ] Bind zoom/recenter to `MapLibreMapController.animateCamera` and detach on dispose.
- [ ] Configure `MapLibreMap` with `scrollGesturesEnabled`, `zoomGesturesEnabled`, `rotateGesturesEnabled`, `tiltGesturesEnabled`, `doubleClickZoomEnabled`, and `dragEnabled` explicitly enabled; provide an eager gesture recognizer for the native platform view.
- [ ] Add widget/unit coverage that verifies native commands are invoked and fake behavior remains unchanged.
- [ ] Run `fvm flutter test test/shared/map/yg_map_test.dart`.

### Task 2: Real stop discovery and API availability

**Files:**
- Modify: `api/src/provider-gateway/adapters/overpass-transit.provider.ts`
- Modify: `api/src/config/configuration.ts`
- Modify: `api/src/provider-gateway/provider-gateway.module.ts`
- Modify: `api/src/transit/application/transit.service.ts` only if the fallback result needs explicit source metadata
- Modify: `api/.env.example` or `api/README.md` if endpoint configuration changes
- Test: existing Overpass provider and transit service tests

**Interfaces:**
- Keep `TransitStopDiscoveryProvider.discoverStops` returning canonical `TransitStopCandidate[]`.
- Add configurable ordered Overpass endpoints, bounded retries, and parsing for node/way/area center coordinates without leaking raw tags.

- [ ] Add a comma-separated endpoint configuration with the current `OVERPASS_BASE_URL` first and public fallback endpoints after it.
- [ ] Keep requests serialized and bounded; retry only transient HTTP failures/timeouts, never malformed payloads.
- [ ] Expand the query to include bus-stop nodes and transit platforms/stop positions represented by nodes or ways, using `out center tags` where needed.
- [ ] Preserve the fifteen-minute cache and `sourceAuthorized: true` for OSM data; no ETA or live vehicle fields are introduced.
- [ ] Test endpoint fallback, transient retry, invalid coordinate filtering, and canonical mapping.
- [ ] Restart the API, verify `/v1/health`, `/v1/places/search`, and `/v1/transit/stops/nearby` through the configured tunnel.

### Task 3: Planner address selection and swap behavior

**Files:**
- Modify: `yegamo_app/lib/modules/planner/pages/planner_page.dart`
- Modify: `yegamo_app/lib/modules/planner/widgets/planner_common.dart` only if a reusable address-result widget is needed
- Modify: `yegamo_app/lib/modules/search/services/search_repository.dart` only if a non-recents place lookup is needed
- Modify: `yegamo_app/lib/modules/onboarding/task_five_app.dart` only if a provider must be registered
- Test: `yegamo_app/test/modules/planner/planner_pages_test.dart`

**Interfaces:**
- Keep `JourneyPoint` and `JourneyPlanRequest` coordinate-based.
- Planner fields expose labels to the user and store a selected `PlaceResult`/`JourneyPoint` internally.
- Search executes on keyboard submit or search action, not on every keystroke, respecting public Nominatim usage limits.

- [ ] Replace coordinate keyboard/input formatters with text address fields and location/search icons.
- [ ] Initialize origin with current location in memory when permission is granted; otherwise leave it selectable by address.
- [ ] Search the active field through `SearchViewModel` and render canonical results below the origin/destination card.
- [ ] Selecting a result stores its coordinates, displays its label, and dismisses the keyboard without persisting precise user location.
- [ ] Clear the stored point when its text is edited.
- [ ] Swap both labels and stored points atomically, including the route-argument destination case.
- [ ] Validate that both points are selected and use address-oriented error text.
- [ ] Test selection, editing invalidation, swap, and journey request coordinates.

### Task 4: Keyboard-safe sheets and modals

**Files:**
- Modify: `yegamo_app/lib/shared/design_system/yg_sheet.dart`
- Modify: `yegamo_app/lib/modules/planner/widgets/planner_common.dart`
- Modify: `yegamo_app/lib/modules/search/pages/search_page.dart` only if page-level inset handling conflicts with the shared sheet
- Test: `yegamo_app/test/shared/design_system/yg_sheet_test.dart` if present, otherwise add a focused widget test

**Interfaces:**
- `YgSheet` computes a visual height from `MediaQuery.viewInsets.bottom` and moves its bottom edge above the keyboard.
- `showYgModalSheet` constrains its material surface to the visible height and keeps its content scrollable.

- [ ] Derive available sheet height from screen height minus keyboard inset and clamp the configured height without changing snap semantics.
- [ ] Add bottom inset to the rendered sheet position and preserve rounded surface boundaries.
- [ ] Ensure `SheetScroll` and modal bodies can scroll to the focused field and retain bottom padding.
- [ ] Keep map controls and map camera calculations stable while a sheet is resized.
- [ ] Add tests that pump a keyboard inset and verify the planner/search fields remain visible and no overflow occurs.

### Task 5: Verification and manual tunnel smoke test

**Files:**
- No new production files unless test failures require focused fixes.

- [ ] Run `fvm flutter analyze`.
- [ ] Run the full Flutter test suite.
- [ ] Run API typecheck, build, and tests.
- [ ] Run `git diff --check`.
- [ ] Verify the tunnel URL returns health, real place results for `terminal`, and nearby stops for a Guayaquil coordinate.
- [ ] Report any provider outage as degraded/unavailable instead of substituting demo data.

## Self-review checklist

- Map gestures, native controls, real markers, address selection, swap, keyboard layout, and API recovery each have an explicit task and verification.
- The plan does not add a second routing provider or persist user coordinates.
- The plan keeps public OSM/Nominatim usage bounded and behind the API.
- No commit step is included because the user explicitly prohibited commits until further notice.
