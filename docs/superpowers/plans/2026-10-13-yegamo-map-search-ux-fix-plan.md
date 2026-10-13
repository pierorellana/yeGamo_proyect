# yeGamo Map and Search UX Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use inline execution for this plan because the user requested implementation in the current workspace. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mantener nítido el mapa real y hacer que la búsqueda manual por túnel muestre resultados cercanos sin que el teclado o respuestas antiguas rompan el flujo.

**Architecture:** Las superficies que se superponen al `MapLibreMap` seguirán usando el sistema visual de yeGamo pero con composición opaca/translúcida sin `BackdropFilter`. El cliente enviará una coordenada efímera al repositorio de búsqueda cuando el sistema la permita; el gateway añadirá filtros geográficos seguros para Nominatim, ampliará el deadline de proveedor y conservará únicamente el contrato `Place`.

**Tech Stack:** Flutter/Dart, `maplibre_gl`, NestJS, TypeScript, Nominatim Search API, Flutter Test, Jest/Supertest.

## Global Constraints

- No realizar commits nuevos hasta instrucción explícita del usuario.
- No versionar la URL del túnel, secretos ni credenciales.
- Nominatim se consulta solo mediante Buscar/Enter; no se agrega autocomplete por tecla.
- La coordenada enviada a lugares es transitoria y no se persiste.
- Las respuestas de proveedor se convierten al contrato canónico sin DTOs externos.
- El mapa real conserva atribución OSM cuando usa el fallback raster.
- Validar con pruebas focalizadas, suites aplicables, `flutter analyze`, `npm run typecheck` y `git diff --check`.

---

### Task 1: Documentar la corrección

**Files:**
- Modify: `docs/superpowers/specs/2026-10-13-yegamo-real-map-and-places-design.md`
- Create: `docs/superpowers/plans/2026-10-13-yegamo-map-search-ux-fix-plan.md`

- [x] **Step 1: Registrar la causa y las decisiones**

  La spec registra el blur causado por `BackdropFilter` sobre la vista nativa,
  la consulta manual explícita, el sesgo geográfico transitorio y el deadline
  de 5 segundos para el proveedor.

- [x] **Step 2: Revisar consistencia**

  La spec no introduce migraciones, autocomplete, persistencia de
  coordenadas, claves de mapas ni DTOs de Nominatim en Flutter.

### Task 2: Corregir la composición sobre el mapa

**Files:**
- Modify: `yegamo_app/lib/shared/design_system/yg_surfaces.dart`
- Modify: `yegamo_app/lib/modules/home/widgets/home_widgets.dart`
- Modify: `yegamo_app/lib/shared/map/yg_map_controls.dart`
- Modify: `yegamo_app/lib/modules/planner/widgets/planner_common.dart`
- Modify: `yegamo_app/lib/modules/nearby/widgets/map_top_row.dart`
- Modify: `yegamo_app/lib/modules/journey/widgets/arrival_widgets.dart`
- Modify: `yegamo_app/lib/modules/search/widgets/no_coverage_view.dart`
- Modify: `yegamo_app/lib/shared/design_system/yg_sheet.dart`
- Modify: `yegamo_app/lib/shared/design_system/yg_controls.dart`
- Test: `yegamo_app/test/shared/design_system/yg_surfaces_test.dart`

**Interfaces:**
- `YgGlass(blur: 0)` produce una superficie visual equivalente sin crear un
  `BackdropFilter`.
- Las cabeceras, controles, tab bar y barras del flujo de mapa usarán esa
  variante sin blur; las superficies fuera del mapa conservan el blur actual.

- [x] **Step 1: Escribir la prueba de ausencia de filtro**

  Crear una prueba que monte `YgGlass(blur: 0, child: SizedBox())` y compruebe
  que no existe `BackdropFilter`; montar también `YgGlass(blur: 20, ...)` y
  comprobar que sí existe.

- [x] **Step 2: Ejecutar la prueba y confirmar el fallo**

  ```bash
  cd yegamo_app
  fvm flutter test test/shared/design_system/yg_surfaces_test.dart
  ```

  Resultado esperado antes del cambio: falla la variante `blur: 0` porque el
  widget siempre envuelve el contenido en `BackdropFilter`.

- [x] **Step 3: Implementar la rama sin blur**

  En `YgGlass`, construir el `Container` una sola vez y envolverlo en
  `BackdropFilter` únicamente cuando `blur > 0`. Pasar `blur: 0` a los
  elementos que se dibujan sobre mapas y usar botones secundarios equivalentes
  para no crear vidrios individuales sobre el mapa.

- [x] **Step 4: Validar superficies y análisis**

  ```bash
  fvm flutter test test/shared/design_system/yg_surfaces_test.dart
  fvm flutter analyze
  ```

  Resultado esperado: PASS; ningún overlay de Inicio, Cerca, Planificador o
  viaje activo crea un filtro de fondo sobre el mapa nativo.

### Task 3: Corregir el panel de búsqueda y el teclado

**Files:**
- Modify: `yegamo_app/lib/modules/search/pages/search_page.dart`
- Test: `yegamo_app/test/modules/search/search_page_test.dart`

**Interfaces:**
- El foco de `search_query` no cambia `_sheet` a `YgSnap.max`.
- La búsqueda explícita vuelve a `YgSnap.mid` y el Scaffold no redimensiona el
  mapa al aparecer el teclado.

- [x] **Step 1: Añadir una prueba de foco**

  Asignar key `search_sheet` a `YgSheet`, tocar `search_query` y comprobar que
  su posición no corresponde a la altura máxima. Después enviar una consulta y
  comprobar que la hoja vuelve a su posición media.

- [x] **Step 2: Ejecutar la prueba y confirmar el fallo**

  ```bash
  fvm flutter test test/modules/search/search_page_test.dart
  ```

  Resultado esperado antes del cambio: la hoja se anima a `YgSnap.max` por el
  listener de `_focus`.

- [x] **Step 3: Implementar el comportamiento de teclado**

  Eliminar el `setSnap(YgSnap.max)` del listener de foco, añadir
  `resizeToAvoidBottomInset: false`, asignar la key estable y ejecutar
  `_sheet.setSnap(YgSnap.mid)` al completar el submit.

- [x] **Step 4: Ejecutar la prueba focalizada**

  ```bash
  fvm flutter test test/modules/search/search_page_test.dart
  ```

  Resultado esperado: el campo permanece visible, la hoja no cubre el mapa al
  enfocar y las pruebas existentes de resultados siguen pasando.

### Task 4: Habilitar búsqueda geográfica tolerante al túnel

**Files:**
- Modify: `yegamo_app/lib/modules/search/services/search_repository.dart`
- Modify: `yegamo_app/lib/modules/onboarding/task_five_app.dart`
- Modify: `yegamo_app/test/modules/search/search_test.dart`
- Modify: `api/src/provider-gateway/adapters/nominatim-geocoding.provider.ts`
- Modify: `api/src/provider-gateway/application/geocoding-gateway.service.ts`
- Modify: `api/test/provider-gateway/nominatim-geocoding.provider.spec.ts`
- Modify: `api/test/provider-gateway/provider-gateway.spec.ts`

**Interfaces:**
- `SearchRepository` acepta `LocationService` y añade `lat`/`lon` solo si
  `currentPosition()` devuelve una coordenada válida; la inyección es opcional
  para conservar repositorios de pruebas aisladas.
- Nominatim recibe `countrycodes=ec`; con `near` recibe además un `viewbox`
  alrededor del origen, sin usar `bounded=1`.
- `DEFAULT_GEOCODING_TIMEOUT_MS` pasa de 2000 a 5000 ms.

- [x] **Step 1: Añadir pruebas de query geográfica y timeout**

  Verificar en Flutter que un `FakeLocationService` con posición envía `q`,
  `lat` y `lon`. Verificar en TypeScript que la URL contiene `countrycodes=ec`
  y un `viewbox` ordenado como `lonMin,latMax,lonMax,latMin`. Verificar que el
  timeout exportado vale 5000.

- [x] **Step 2: Ejecutar pruebas y confirmar el fallo**

  ```bash
  cd yegamo_app
  fvm flutter test test/modules/search/search_test.dart
  cd ../api
  npm test -- --runInBand --watchman=false test/provider-gateway/nominatim-geocoding.provider.spec.ts test/provider-gateway/provider-gateway.spec.ts
  ```

  Resultado esperado antes del cambio: la petición Flutter solo contiene `q`,
  la URL no contiene `countrycodes`, y el deadline continúa en 2000 ms.

- [x] **Step 3: Implementar parámetros y deadline**

  Leer la posición dentro de la búsqueda explícita, agregar `lat` y `lon` al
  query sin guardarla, y en el adapter construir la ventana geográfica a
  partir de `near`. Exportar la constante y usarla en el gateway.

- [x] **Step 4: Validar la ruta HTTP**

  ```bash
  npm test -- --runInBand --watchman=false test/places/places.spec.ts test/provider-gateway/nominatim-geocoding.provider.spec.ts test/provider-gateway/provider-gateway.spec.ts
  npm run typecheck
  ```

  Resultado esperado: el contrato sigue devolviendo únicamente `id`, `label`,
  `location`, `source` y `dataState`.

### Task 5: Evitar respuestas de solicitudes antiguas

**Files:**
- Modify: `yegamo_app/lib/modules/search/providers/search_view_model.dart`
- Test: `yegamo_app/test/modules/search/search_view_model_test.dart`

**Interfaces:**
- `SearchViewModel.search()` conserva solo el snapshot de la última búsqueda
  iniciada y no cambia el estado cuando termina una petición anterior.

- [x] **Step 1: Escribir la prueba de carrera**

  Crear un fake repository con dos `Completer<SearchSnapshot>`; iniciar la
  búsqueda `terminal`, iniciar luego `malecón`, completar primero `terminal` y
  comprobar que el snapshot no cambia a `terminal`; completar `malecón` y
  comprobar que sus resultados quedan visibles.

- [x] **Step 2: Ejecutar la prueba y confirmar el fallo**

  ```bash
  fvm flutter test test/modules/search/search_view_model_test.dart
  ```

  Resultado esperado antes del cambio: la primera respuesta sobrescribe el
  snapshot aunque la segunda búsqueda esté en curso.

- [x] **Step 3: Añadir un contador de solicitudes**

  Incrementar un token al comenzar cada `search` y aplicar el snapshot solo si
  el token sigue vigente; mantener `_loading` y `notifyListeners()` coherentes
  con la solicitud activa.

- [x] **Step 4: Ejecutar la prueba focalizada**

  ```bash
  fvm flutter test test/modules/search/search_view_model_test.dart test/modules/search/search_page_test.dart
  ```

### Task 6: Revisión final

- [x] **Step 1: Ejecutar las suites aplicables**

  ```bash
  cd api
  npm test -- --runInBand --watchman=false
  npm run typecheck
  cd ../yegamo_app
  fvm flutter test
  fvm flutter analyze
  ```

- [x] **Step 2: Revisar cambios y formato**

  ```bash
  cd ..
  git diff --check
  git status --short
  rg -n "DEBUG-|TODO|TBD" yegamo_app/lib api/src docs/superpowers/specs/2026-10-13-yegamo-real-map-and-places-design.md docs/superpowers/plans/2026-10-13-yegamo-map-search-ux-fix-plan.md
  ```

  Resultado esperado: sin logs de diagnóstico, sin placeholders, sin commit y
  únicamente archivos relacionados con este arreglo además de los cambios
  preexistentes del usuario.
