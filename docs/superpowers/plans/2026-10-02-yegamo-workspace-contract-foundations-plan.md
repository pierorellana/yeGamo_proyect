# yeGamo Workspace and Contract Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Crear el workspace SDD de yeGamo, consolidar las especificaciones v1.1 y publicar un contrato OpenAPI completo que sirva de frontera entre el API NestJS y la app Flutter.

**Architecture:** Un único workspace Git con `context/`, `yegamo_app/` y `api/`. El API será un monolito modular NestJS; este plan solo crea sus fundaciones documentales y contractuales, dejando la implementación de módulos, migraciones y UI para planes independientes.

**Tech Stack:** Markdown, JSON, YAML/OpenAPI 3.1, Flutter existente, Node.js + TypeScript/NestJS como destino del API, PostgreSQL + PostGIS como destino de persistencia, `provider` + `ChangeNotifier` para la app.

## Global Constraints

- El paquete v1.1 define comportamiento y contratos; el prototipo define referencia visual y de flujo.
- El MVP se valida primero en Guayaquil.
- Las 17 pantallas del prototipo y los 9 estados UX son baseline de producto.
- La app Flutter conserva la arquitectura `env/modules/shared` con `provider`, `ChangeNotifier`, `MaterialApp`, rutas nombradas, `Navigator` e `IndexedStack`.
- El API usa NestJS + TypeScript y REST/JSON versionado bajo `/v1`.
- PostgreSQL + PostGIS es la base de datos objetivo.
- Los datos del prototipo, incluyendo `RutaYa`, `Metrovia GTFS`, horarios y scores, son demo y no pueden convertirse en defaults productivos.
- El modo invitado permite planificar y guardar localmente; sincronizar a cuenta requiere una operación explícita e idempotente.
- Una posición solo es `LIVE` con fuente autorizada y timestamp reciente.
- No se agregan microservicios ni WebSocket/SSE al MVP.
- No se agregan endpoints o códigos de error que no estén descritos en el contrato o en una decisión registrada.

---

### Task 1: Crear la gobernanza del workspace SDD

**Files:**
- Create: `AGENTS.md`
- Create: `context/README.md`
- Create: `context/architecture/current-architecture.md`
- Create: `context/architecture/integration-boundaries.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-10-02-yegamo-platform-foundations-design.md`.
- Produces: reglas de precedencia, topología de workspace, límites de integración y flujo SDD que usarán todos los planes posteriores.

- [ ] **Step 1: Escribir `AGENTS.md` con la precedencia y la topología aprobadas**

  Incluir exactamente estas reglas de alto nivel:

  ```markdown
  # yeGamo — mapa del workspace

  El workspace raíz contiene `context/`, `yegamo_app/` y `api/`. Nunca se abre una superficie aislada sin leer este archivo y el README de `context/`.

  Precedencia: comportamiento y contratos en `context/specs/`; flujo y look en `context/prototype/`; decisiones técnicas en `context/adr/`; ejecución en `docs/superpowers/plans/`.

  SDD: spec → diseño/ADR → plan → implementación → pruebas → revisión → cierre.

  Invariantes: no inventar ETA; no mostrar LIVE sin fuente y timestamp; no exponer DTOs de proveedores; no persistir ubicación precisa sin consentimiento; no almacenar contraseñas; no usar datos demo como producción.

  Antes de tocar Flutter, leer `yegamo_app/AGENTS.md` si existe. Antes de tocar API o migraciones, leer `api/AGENTS.md` si existe.
  ```

- [ ] **Step 2: Escribir `context/README.md` como índice operativo**

  Documentar las carpetas `specs`, `adr`, `architecture`, `plans` y `prototype`; declarar que `context/specs` es fuente de comportamiento, `api/contracts/openapi.yaml` es fuente del contrato HTTP y `api/db/migrations` es fuente del esquema SQL.

- [ ] **Step 3: Escribir los límites entre app, API, proveedores y base**

  En `context/architecture/current-architecture.md`, documentar que Flutter presenta y coordina; NestJS autoriza y decide; el gateway normaliza proveedores; PostgreSQL persiste; y los workers ejecutan tareas fuera de la petición.

  En `context/architecture/integration-boundaries.md`, incluir esta tabla:

  | Capa | Puede hacer | No puede hacer |
  |---|---|---|
  | Flutter widget | interacción, presentación, navegación | HTTP, reglas de negocio, autorización |
  | Flutter provider/service | cargar, mapear, persistir localmente | decidir confiabilidad, inventar ETA |
  | API application/domain | reglas, ranking, autorización, calidad | renderizar UI |
  | Provider gateway | consultar y normalizar proveedores | publicar DTO propietario |
  | Persistencia | guardar datos autorizados y constraints | decidir copy o estado visual |

- [ ] **Step 4: Añadir artefactos locales al `.gitignore`**

  Confirmar que `.superpowers/`, `api/node_modules/`, `api/dist/`, `api/coverage/`, `api/.env`, `yegamo_app/.dart_tool/`, `yegamo_app/build/` y `yegamo_app/coverage/` estén ignorados sin ignorar `api/.env.example`.

- [ ] **Step 5: Verificar la gobernanza**

  Run: `rg -n "Precedencia|SDD|LIVE|ETA|DTO|PostGIS|OpenAPI" AGENTS.md context/README.md context/architecture`

  Expected: cada término aparece al menos una vez y no hay referencias a Star Circle, RutaYa como marca vigente, Riverpod o `go_router`.

- [ ] **Step 6: Commit**

  ```bash
  git add AGENTS.md context/README.md context/architecture .gitignore
  git commit -m "docs: establish yeGamo SDD workspace governance"
  ```

### Task 2: Incorporar y normalizar el paquete de specs v1.1

**Files:**
- Create: `context/specs/00_README.md`
- Create: `context/specs/01_PRODUCT_REQUIREMENTS.md`
- Create: `context/specs/02_BUSINESS_RULES.md`
- Create: `context/specs/03_FUNCTIONAL_REQUIREMENTS.md`
- Create: `context/specs/04_NON_FUNCTIONAL_REQUIREMENTS.md`
- Create: `context/specs/05_USE_CASES.md`
- Create: `context/specs/06_USER_STORIES.md`
- Create: `context/specs/07_DOMAIN_MODEL.md`
- Create: `context/specs/08_MVP_SCOPE_ROADMAP.md`
- Create: `context/specs/09_EXTERNAL_DATA_RESEARCH.md`
- Create: `context/specs/10_INTEGRATION_STRATEGY.md`
- Create: `context/specs/11_API_SPEC.md`
- Create: `context/specs/12_OPENAPI.yaml`
- Create: `context/specs/13_DATABASE_SPEC.md`
- Create: `context/specs/14_SCHEMA.sql`
- Create: `context/specs/15_MOBILE_FLUTTER_SPEC.md`
- Create: `context/specs/16_BACKEND_NODE_SPEC.md`
- Create: `context/specs/17_SECURITY_PRIVACY.md`
- Create: `context/specs/18_ANALYTICS_METRICS.md`
- Create: `context/specs/19_TESTING_ACCEPTANCE.md`
- Create: `context/specs/20_RISKS_ASSUMPTIONS.md`
- Create: `context/specs/21_ADR.md`
- Create: `context/specs/22_GLOSSARY.md`
- Create: `context/specs/23_SOURCE_REFERENCES.md`
- Create: `context/specs/24_PROTOTYPE_TRACEABILITY.md`
- Create: `context/specs/25_DESIGN_SYSTEM.md`
- Create: `context/specs/CHANGELOG.md`
- Create: `context/specs/manifest.json`

**Interfaces:**
- Consumes: extracted files from `yeGamo_Specs_v1.1.zip` and the approved design document.
- Produces: a canonical, self-consistent spec package for all later implementation plans.

- [ ] **Step 1: Copiar el paquete v1.1 al contexto canónico**

  Extraer los 29 archivos del directorio `yeGamo_Specs_v1.1/` a `context/specs/`, preservando los nombres publicados y sin copiar la carpeta contenedora.

- [ ] **Step 2: Actualizar la baseline Flutter**

  En `00_README.md` y `15_MOBILE_FLUTTER_SPEC.md`, reemplazar la decisión `Riverpod`/`go_router`/`Dio` por:

  ```text
  Arquitectura: lib/env + lib/modules + lib/shared.
  Estado: provider + ChangeNotifier + MultiProvider.
  Navegación: MaterialApp + rutas nombradas + Navigator + IndexedStack.
  HTTP: servicio compartido único con auth, traceId, timeout, retry controlado y mapeo de errores.
  ```

  Mantener `presentation/domain/data` fuera de la spec móvil como estructura obligatoria; cada módulo usará `pages`, `widgets`, `models`, `providers` y `services`.

- [ ] **Step 3: Actualizar dominio, API y datos**

  En `07_DOMAIN_MODEL.md`, agregar `JourneyLeg`, `JourneyEvent`, `UserPreference`, `DeviceInstallation`, `NotificationDelivery`, `DataExportRequest` y `ProviderHealthSnapshot`.

  En `11_API_SPEC.md` y `12_OPENAPI.yaml`, agregar `GET /v1/me`, `POST /v1/me/guest-migration`, `POST /v1/me/devices`, `DELETE /v1/me/devices/{id}` y los endpoints declarados en la spec que falten en el YAML.

  En `13_DATABASE_SPEC.md` y `14_SCHEMA.sql`, declarar que el SQL publicado pasa a dividirse en migraciones bajo `api/db/migrations`; conservar `14_SCHEMA.sql` como referencia derivada marcada con la misma versión del esquema.

- [ ] **Step 4: Alinear pruebas y trazabilidad**

  En `19_TESTING_ACCEPTANCE.md`, incluir migraciones desde cero y desde versión anterior, guest migration idempotente, registro de dispositivos, estados `OFFLINE_CACHE`/`STALE` y validación de que `LIVE` requiere fuente/timestamp.

  En `24_PROTOTYPE_TRACEABILITY.md`, mantener exactamente 17 pantallas y 9 estados como baseline, y registrar como deuda los textos `RutaYa`, `Metrovia GTFS`, conteo de 16 pantallas y cifras simuladas.

- [ ] **Step 5: Actualizar changelog y manifest**

  `manifest.json` debe declarar `version: 1.1.1`, `prototypeScreens: 17`, `prototypeStates: 9`, `mobileArchitecture: "env-modules-shared-provider"` y `apiContract: "openapi-3.1-v1"`.

  `CHANGELOG.md` debe agregar una entrada con la normalización arquitectónica y la ampliación del contrato, sin borrar la entrada histórica v1.1.

- [ ] **Step 6: Verificar la spec normalizada**

  Run: `rg -n "Riverpod|go_router|Dio|RutaYa|Metrovia GTFS|16 pantallas|8 estados" context/specs`

  Expected: las únicas coincidencias de `RutaYa`/`Metrovia GTFS` están en secciones que las identifican como deuda histórica o dato demo; no quedan referencias normativas a Riverpod, `go_router` o Dio.

- [ ] **Step 7: Commit**

  ```bash
  git add context/specs
  git commit -m "docs: normalize yeGamo v1.1 specifications"
  ```

### Task 3: Registrar las decisiones arquitectónicas aprobadas

**Files:**
- Create: `context/adr/ADR-001-workspace-and-sdd.md`
- Create: `context/adr/ADR-002-modular-nestjs-api.md`
- Create: `context/adr/ADR-003-flutter-modular-architecture.md`
- Create: `context/adr/ADR-004-sql-first-migrations-and-data-access.md`
- Create: `context/adr/ADR-005-provider-gateway-and-honest-data.md`
- Create: `context/adr/README.md`

**Interfaces:**
- Consumes: approved design document and normalized specs.
- Produces: decisions que no deberán reabrirse durante la implementación sin un ADR de cambio.

- [ ] **Step 1: Escribir ADR-001 de workspace y SDD**

  Declarar como decisión un único repositorio raíz con `context/`, `yegamo_app/` y `api/`; documentar la secuencia SDD y la precedencia `specs → prototype → ADR → plan`.

- [ ] **Step 2: Escribir ADR-002 de API**

  Declarar monolito modular NestJS, módulos por dominio, núcleo de planificación independiente del framework, worker separado dentro del mismo código y sin microservicios/WebSocket en MVP.

- [ ] **Step 3: Escribir ADR-003 de Flutter**

  Declarar `env/modules/shared`, `provider`, `ChangeNotifier`, `MultiProvider`, `MaterialApp`, rutas nombradas, `Navigator`, `IndexedStack`, cliente HTTP y regla de consolidar capacidades reutilizables en `shared`.

- [ ] **Step 4: Escribir ADR-004 de datos**

  Declarar SQL-first como fuente de verdad, migraciones deterministas, Prisma Client para CRUD y `pg` crudo solo para PostGIS/locking/concurrencia con justificación en archivo.

- [ ] **Step 5: Escribir ADR-005 de proveedores**

  Declarar gateway canónico, `DemoTransitProvider` solo en desarrollo/pruebas, adapters productivos configurables, fallback y prohibición de mostrar fuentes demo o `LIVE` no autorizado.

- [ ] **Step 6: Crear índice y enlaces**

  `context/adr/README.md` debe listar cada ADR, su estado `accepted`, fecha `2026-10-02`, alcance y relación con las specs afectadas.

- [ ] **Step 7: Verificar ADRs y commit**

  Run: `rg -n "Estado:.*accepted|Decisión|Consecuencias|Alternativas|Cómo se verifica" context/adr`

  Expected: los cinco ADRs contienen estado, decisión, consecuencias, alternativa descartada y verificación.

  ```bash
  git add context/adr
  git commit -m "docs: record yeGamo architecture decisions"
  ```

### Task 4: Publicar la frontera de contrato OpenAPI

**Files:**
- Create: `api/README.md`
- Create: `api/contracts/README.md`
- Create: `api/contracts/openapi.yaml`
- Create: `api/contracts/examples/journey-plan-request.json`
- Create: `api/contracts/examples/journey-plan-response.json`
- Create: `api/contracts/examples/error.json`
- Modify: `context/specs/12_OPENAPI.yaml`

**Interfaces:**
- Consumes: `context/specs/11_API_SPEC.md`, `context/specs/12_OPENAPI.yaml`, domain model and approved API architecture.
- Produces: contrato OpenAPI 3.1 que el API implementará y Flutter consumirá.

- [ ] **Step 1: Escribir metadata, servidores y seguridad**

  `api/contracts/openapi.yaml` debe declarar `openapi: 3.1.0`, `info.title: yeGamo API`, `info.version: 1.1.1`, un servidor `/v1`, tags por dominio y `bearerAuth` OIDC. Las rutas públicas omitirán security; las rutas de cuenta declararán `security: [{bearerAuth: []}]`.

- [ ] **Step 2: Declarar schemas canónicos**

  Incluir como mínimo estos schemas con propiedades, tipos y ejemplos reales: `GeoPoint`, `Place`, `TransitAgency`, `TransitRoute`, `TransitStop`, `JourneyPlanRequest`, `JourneyPlanResponse`, `JourneyOption`, `JourneyLeg`, `ETAEstimate`, `Reliability`, `DataQuality`, `ActiveJourney`, `CommuteProfile`, `LeaveAlert`, `Notification`, `DeviceInstallation`, `UserPreferences`, `PaginatedNotifications` y `Error`.

  `JourneyOption.dataQuality` debe incluir `freshness`, `dataState`, `liveVehicle`, `observedAt` y `providerDisplayName`; el nombre del proveedor será nullable y nunca tendrá `Metrovia GTFS` como ejemplo productivo.

- [ ] **Step 3: Declarar paths completos**

  Publicar las rutas de salud, lugares, cercanía, journeys, viajes activos, favoritos, rutinas, alertas, notificaciones, preferencias, privacidad, migración invitado→cuenta y dispositivos listadas en la spec normalizada. Las rutas community se publican bajo un tag post-MVP y no serán requisito de la primera implementación.

- [ ] **Step 4: Declarar respuestas y headers compartidos**

  Cada operación debe documentar `200`, `201`, `204`, `400`, `401`, `403`, `404`, `409`, `422`, `429` o `503` según corresponda. Las operaciones idempotentes deben declarar el header `Idempotency-Key`; las respuestas deben declarar `traceId` mediante el schema `Error` o header documentado.

- [ ] **Step 5: Escribir ejemplos de contrato**

  `journey-plan-request.json` debe contener `ARRIVE_BY`, origen/destino de Guayaquil, preferencia `RELIABLE`, máximo de caminata y margen extra. `journey-plan-response.json` debe mostrar ventana de llegada, opción con leg `WALK`, opción `TRANSIT`, `dataState: CURRENT`, `liveVehicle: false` y `providerDisplayName: null`. `error.json` debe mostrar `PROVIDER_TIMEOUT` y `traceId`.

- [ ] **Step 6: Documentar el flujo de verificación**

  `api/contracts/README.md` debe indicar que `openapi.yaml` es la fuente canónica, que `context/specs/12_OPENAPI.yaml` se sincroniza desde él y que ningún controller se agrega sin actualizar contrato, ejemplo y prueba de contrato en la misma corrida.

- [ ] **Step 7: Validar sintaxis y referencias**

  Run: `python3 -c "import yaml; yaml.safe_load(open('api/contracts/openapi.yaml'))"`

  Expected: salida vacía y código 0.

  Run: `rg -n "JourneyPlanRequest|JourneyPlanResponse|JourneyOption|JourneyLeg|DataQuality|Idempotency-Key|bearerAuth" api/contracts/openapi.yaml`

  Expected: cada término aparece en una definición o path; no aparece `Metrovia GTFS` fuera de texto explícito de demo.

- [ ] **Step 8: Commit**

  ```bash
  git add api/README.md api/contracts context/specs/12_OPENAPI.yaml
  git commit -m "feat: publish yeGamo v1 REST contract"
  ```

### Task 5: Crear la matriz de trazabilidad de fundaciones

**Files:**
- Create: `context/architecture/traceability.md`
- Create: `context/prototype/README.md`
- Create: `context/prototype/screens/yeGamo-mobile.md`
- Create: `context/prototype/DESIGN-TOKENS.md`

**Interfaces:**
- Consumes: `context/specs/24_PROTOTYPE_TRACEABILITY.md`, `context/specs/25_DESIGN_SYSTEM.md` y el HTML del prototipo.
- Produces: referencia verificable entre pantalla, requerimiento, estado, componente y futura feature Flutter.

- [ ] **Step 1: Crear la tabla de pantallas**

  `context/prototype/screens/yeGamo-mobile.md` debe listar las 17 pantallas con columnas `screen`, `responsibility`, `requirements`, `flutterModule`, `apiRoutes`, `states` y `demoDataNotes`.

- [ ] **Step 2: Crear tokens visuales**

  `DESIGN-TOKENS.md` debe declarar los colores `#0C0C0C`, `#121212`, `#252525`, `#235E5D`, `#F5F5F5`, `#8C8C8E`, `#9A9A9D`; tipografías/escala; radios; spacing; targets táctiles; y la regla de diferenciar LIVE/ESTIMATED por texto y forma.

- [ ] **Step 3: Crear trazabilidad transversal**

  `context/architecture/traceability.md` debe mapear requisitos `RF`, endpoints OpenAPI, tablas principales, módulos Flutter y pruebas de aceptación. Incluir una fila para cada grupo `RF-001..005`, `RF-010..014`, `RF-020..024`, `RF-030..044`, `RF-050..056`, `RF-060..074`, `RF-080..092`.

- [ ] **Step 4: Documentar el límite del prototipo**

  `context/prototype/README.md` debe decir que el prototipo es autoridad visual/flujo, no fuente de horarios, scores, fuentes ni disponibilidad real; la integración productiva depende del API y configuración de proveedores.

- [ ] **Step 5: Verificar cobertura**

  Run: `rg -n "Splash|Onboarding|Permisos|Inicio|Buscar|Cercano|Planificador|Cargando|Alternativas|Cuándo salir|Paso a paso|Viaje activo|Alerta de bajada|Guardados|Rutinas|Avisos|Ajustes" context/prototype/screens/yeGamo-mobile.md`

  Expected: 17 nombres presentes; `Cargando` no se omite.

- [ ] **Step 6: Commit**

  ```bash
  git add context/architecture/traceability.md context/prototype
  git commit -m "docs: add yeGamo prototype traceability baseline"
  ```

### Task 6: Ejecutar el gate de fundaciones y cerrar el subproyecto

**Files:**
- Create: `context/plans/FOUNDATIONS-CLOSEOUT.md`
- Modify: `context/README.md`

**Interfaces:**
- Consumes: todos los documentos, ADRs y `api/contracts/openapi.yaml` creados en Tasks 1–5.
- Produces: evidencia de que el contexto y el contrato están listos para los planes de API/base y Flutter.

- [ ] **Step 1: Verificar sintaxis de JSON y YAML**

  Run: `python3 -c "import json, pathlib, yaml; json.load(open('context/specs/manifest.json')); yaml.safe_load(open('api/contracts/openapi.yaml')); print('foundations syntax: ok')"`

  Expected: `foundations syntax: ok`.

- [ ] **Step 2: Verificar ausencia de decisiones obsoletas**

  Run: `rg -n "Riverpod|go_router|Metrovia GTFS|16 pantallas|8 estados" context api/contracts`

  Expected: solo referencias históricas o explícitamente demo; cero referencias normativas a Riverpod o `go_router`.

- [ ] **Step 3: Verificar trazabilidad mínima**

  Run: `test "$(rg -o 'RF-[0-9]+' context/architecture/traceability.md | sort -u | wc -l | tr -d ' ')" -ge 8 && test "$(rg -o 'Cargando' context/prototype/screens/yeGamo-mobile.md | wc -l | tr -d ' ')" -ge 1 && echo 'traceability: ok'`

  Expected: `traceability: ok`.

- [ ] **Step 4: Registrar el cierre**

  `FOUNDATIONS-CLOSEOUT.md` debe incluir: fecha `2026-10-02`, commit de cada task, comandos ejecutados, resultado de cada gate, lista de documentos canónicos y los dos siguientes planes requeridos: `api-and-database` y `flutter-app`.

- [ ] **Step 5: Actualizar el índice**

  En `context/README.md`, enlazar el diseño aprobado, este plan, `api/contracts/openapi.yaml`, `context/architecture/traceability.md` y `FOUNDATIONS-CLOSEOUT.md`.

- [ ] **Step 6: Commit final**

  ```bash
  git add context/README.md context/plans/FOUNDATIONS-CLOSEOUT.md
  git commit -m "docs: close yeGamo foundations baseline"
  ```

## Self-review del plan

- Cobertura: Tasks 1–3 cubren workspace, specs y ADRs; Task 4 cubre el contrato; Task 5 cubre prototipo/tokens/trazabilidad; Task 6 cubre gates y cierre.
- Alcance: este plan no implementa NestJS, migraciones SQL ni pantallas Flutter; esos bloques quedan en planes independientes como exige la separación aprobada.
- Consistencia: Flutter usa `provider`/`ChangeNotifier`; API usa NestJS; el contrato usa OpenAPI 3.1; la persistencia SQL-first queda registrada para el siguiente plan.
- Placeholders: no hay `TBD`, `TODO`, pasos genéricos ni referencias a archivos inexistentes como fuente de comportamiento.
- Contrato: guest migration, dispositivos, idempotencia, `dataState`, calidad y errores están cubiertos por Task 4 y se reflejan en trazabilidad.

