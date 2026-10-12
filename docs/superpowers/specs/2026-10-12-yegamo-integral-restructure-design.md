# yeGamo — Diseño de reestructuración integral

**Fecha:** 2026-10-12  
**Estado:** Aprobado por el usuario para planificación  
**Alcance:** `yegamo_app/`, `api/`, `context/` y los artefactos de referencia del prototipo  
**Estrategia:** SDD por verticales, conservando las rutas físicas actuales

## 1. Objetivo

Reestructurar el workspace de yeGamo para alinear App Flutter, API NestJS,
persistencia, contrato HTTP, documentación SDD y referencia visual con el
prototipo Claude Design y las specs v1.1, sin convertir datos demo en datos de
producción ni introducir un proveedor de transporte/geocodificación no
autorizado.

El resultado debe ser un sistema ejecutable y verificable por cortes: la App
debe navegar las 17 pantallas baseline y sus 9 estados UX; la API debe
implementar el contrato `/v1` con límites modulares; y la documentación debe
describir el sistema realmente implementado.

## 2. Decisiones aprobadas

### 2.1 Rutas físicas y superficies

Se conservan las rutas existentes:

```text
context/       especificaciones, arquitectura, ADR, planes y prototipo
yegamo_app/    cliente Flutter
api/           monolito modular NestJS, worker y persistencia
```

`yegamo_app/` y `api/` son los nombres físicos compatibles con el tooling
actual. `App` y `API` se usarán como nombres lógicos de superficie en la
documentación, no como renombres de directorio.

Los cambios del usuario ya presentes en el worktree se preservan. Los
artefactos adjuntos —HTML, ZIP y PDF— no se eliminan ni se tratan como código
ejecutable del producto sin una decisión explícita.

### 2.2 Estrategia de ejecución

La implementación seguirá verticales ordenadas, y cada vertical incluirá
spec/ADR si aplica, código, pruebas y actualización documental:

0. Fundación compartida.
1. Entrada y contexto.
2. Descubrimiento.
3. Planificación.
4. Viaje activo.
5. Retención y privacidad.
6. Cierre y trazabilidad.

No se hará un big-bang que mezcle todos los módulos sin una superficie
verificable intermedia.

### 2.3 Ausencia de proveedores

No existe todavía un proveedor autorizado de transporte o geocodificación.
Por ello:

- producción no inyectará `DemoTransitProvider` ni un adapter inventado;
- el gateway podrá iniciar sin adapters productivos y devolverá errores
  canónicos de capacidad no disponible;
- los endpoints de movilidad dependientes de proveedor no fabricarán rutas,
  ETA, posiciones, nombres de fuente ni timestamps;
- `DemoTransitProvider` y fixtures visuales solo se habilitarán mediante una
  configuración explícita de desarrollo/pruebas;
- las respuestas demo se clasificarán como `DEGRADED` y no podrán mostrar
  `LIVE`;
- la App representará la indisponibilidad como estado recuperable y no como
  dato actual.

## 3. Estado del workspace de partida

- `yegamo_app/` es todavía el proyecto Flutter de plantilla, con un único
  `main.dart`, un test de widget de ejemplo y sin módulos de producto.
- `api/` contiene la base NestJS, configuración, trazabilidad, salud,
  Prisma, migraciones SQL y el gateway inicial de proveedores, pero aún no
  contiene los módulos funcionales completos del contrato.
- `api/contracts/openapi.yaml` es la frontera HTTP canónica.
- `api/db/migrations/` es la fuente ejecutable del esquema SQL; las specs SQL
  son referencia derivada.
- `context/` ya contiene las specs de producto, la baseline de 17 pantallas,
  los 9 estados, tokens visuales, arquitectura, trazabilidad y decisiones de
  fundación.
- `yeGamo-prototipo.html` y `yeGamo-prototipo-completo.zip` contienen la
  referencia visual, recursos, keyframes, controles de estados y flujo del
  prototipo. Sus lugares, horarios, fuentes, scores y ETA son demo.

## 4. Arquitectura objetivo

### 4.1 App Flutter

La App conservará la arquitectura modular definida en
`context/specs/15_MOBILE_FLUTTER_SPEC.md`:

```text
lib/
  env/
    config/
    theme/
  shared/
    models/
    services/
    security/
    session/
    localization/
    notifications/
    storage/
    location/
    routes/
    navigation/
    widgets/
    design_system/
    analytics/
  modules/
    onboarding/
    permissions/
    home/
    search/
    nearby/
    planner/
    journey/
    saved/
    commutes/
    notifications/
    settings/
```

Cada módulo agrupará sus páginas, widgets, modelos de presentación,
providers/ViewModels y servicios específicos. Las responsabilidades serán:

- **Vista:** composición, interacción de UI, animaciones propias de la
  superficie y navegación declarada.
- **Provider/ViewModel:** estado inmutable observable, comandos de usuario,
  carga, recuperación y transformación hacia modelos de presentación.
- **Servicio:** HTTP, almacenamiento local, ubicación, conectividad o plugin;
  nunca recibe `BuildContext` ni contiene copy de UI.
- **Repositorio:** fuente de verdad de una capacidad, cache y mapeo de DTO
  canónico del API a modelos de App.
- **Dominio compartido:** solo se creará cuando una regla se reutilice o sea
  suficientemente compleja para no pertenecer al ViewModel.

Los widgets no harán HTTP, no leerán DTOs de proveedores y no decidirán si un
dato puede llamarse `LIVE`. La navegación seguirá el contrato de la spec:
rutas nombradas, `Navigator` e `IndexedStack` para las superficies raíz.

### 4.2 API NestJS

`api/` se organizará como monolito modular escalable, no como microservicios:

```text
src/
  identity/
  places/
  transit/
  journeys/
  active-journeys/
  favorites/
  commutes/
  alerts/
  notifications/
  community/
  provider-gateway/
  shared/
  worker/
```

Cada módulo separará controller, DTO HTTP, caso de uso, dominio, puertos,
repositorios y mappers cuando lo requiera. Los controllers solo traducirán
HTTP a comandos/casos de uso. El núcleo de dominio no dependerá de NestJS,
Prisma, `pg` ni de un proveedor externo.

Las responsabilidades de integración serán:

```text
request → trace → auth → validación → controller → caso de uso
        → repositorio/provider gateway → mapper canónico → respuesta /v1
```

El worker comparte casos de uso y código del monolito, pero no cambia el
contrato HTTP ni introduce WebSocket/SSE en el MVP.

### 4.3 Límites

| Superficie | Puede hacer | No puede hacer |
|---|---|---|
| Flutter widget | interacción, presentación, animación y navegación | HTTP, autorización, confiabilidad o ETA |
| App service/repository | cargar, cachear, mapear y persistir localmente | inventar fuente, ETA o estado `LIVE` |
| API application/domain | validar, autorizar, planificar y decidir calidad | renderizar UI o exponer DTO de proveedor |
| Provider gateway | consultar, normalizar, clasificar frescura y fallback | publicar DTO propietario |
| Persistencia | guardar datos autorizados y aplicar constraints | decidir copy visual o estados de UI |

## 5. Pantallas y estados UX

La baseline funcional conserva exactamente estas 17 pantallas:

1. Splash
2. Onboarding
3. Permisos
4. Inicio
5. Buscar
6. Cercano
7. Planificador
8. Cargando
9. Alternativas
10. Hora de salida
11. Paso a paso
12. Viaje activo
13. Alerta de bajada
14. Guardados
15. Rutinas
16. Avisos
17. Ajustes

El estado de llegada que aparece como `arrived` en el HTML se implementará
como estado terminal del módulo de viaje. `nocov` será un estado UX compartido.
Ninguno aumenta el conteo de pantallas.

### 5.1 Agrupación por vertical

| Vertical | Pantallas/capacidades | Resultado verificable |
|---|---|---|
| Entrada | Splash, Onboarding, Permisos, Inicio | primer inicio, permiso concedido/denegado y shell raíz |
| Descubrimiento | Buscar, Cercano | búsqueda, ubicación manual, estado sin cobertura y cache |
| Planificación | Planificador, Cargando, Alternativas, Hora de salida | consulta, cancelación, comparación y alerta de salida |
| Viaje | Paso a paso, Viaje activo, Alerta de bajada, llegada | progreso, estados de calidad, terminar/cancelar |
| Retención | Guardados, Rutinas, Avisos, Ajustes | CRUD, preferencias, guest mode y privacidad |

### 5.2 Estados compartidos

Todos los módulos usarán un modelo compartido que pueda representar:

```text
ok · loading · empty · error · offline · stale · degraded · permission · nocoverage
```

La acción de recuperación estará asociada al motivo: reintentar, volver,
usar origen manual, activar permiso, modificar tiempo, aumentar caminata,
continuar con cache identificada como `OFFLINE_CACHE` o regresar a una
superficie segura.

El cliente nunca convertirá automáticamente un `503` en una ETA local. El
cache solo se presentará con estado y frescura explícitos.

## 6. Diseño visual e interacción

### 6.1 Fuente de verdad

La precedencia visual será `context/specs/` → ADR/diseño aprobado →
`context/prototype/` y HTML/ZIP → implementación. Los assets del ZIP se
incorporarán a `yegamo_app/assets/` conservando su identidad `yeGamo`.

No se reintroducirá `RutaYa` como marca. Los textos y cifras demo se
clasificarán antes de copiarse:

- estructura visual y copy de interacción: reutilizable;
- datos de transporte, nombres de fuente, ETA, scores, horarios y lugares:
  fixture demo o modelo del API, nunca default productivo.

### 6.2 Sistema visual

Se centralizarán los tokens de `context/prototype/DESIGN-TOKENS.md` y los
recursos del ZIP: color oscuro, superficies elevadas discretas, acento teal,
tipografía adaptable, ritmo de 4/8/12/20/26 px, targets de al menos 44 px,
radios de banner/card/sheet/pill y componentes de calidad de datos.

`LIVE` y `ESTIMATED` siempre tendrán copy y forma además del color:

- `LIVE`: solo fuente autorizada + timestamp reciente + `liveVehicle` válido;
- `ESTIMATED`: inferencia explícita, sin semántica de tiempo real;
- `STALE`, `DEGRADED`, `OFFLINE_CACHE`, `UNAVAILABLE`: copy de estado,
  frescura y recuperación.

El layout usará `SafeArea`, `LayoutBuilder`, `MediaQuery.sizeOf`, constraints,
`Expanded`/`Flexible` y listas lazy. No se fijará la lógica a un viewport de
393×852 aunque ese sea el tamaño de referencia del HTML.

### 6.3 Animaciones

Los keyframes del prototipo se traducirán a primitivas Flutter:

- `AnimationController`/curvas para entradas, loading y transiciones;
- `AnimatedSwitcher` para cambios de estado y contenido;
- `Transform` con perspectiva para flip y efectos 3D;
- `CustomPainter` para líneas, composición de ruta e ilustraciones dinámicas;
- `DraggableScrollableSheet` o equivalente para bottom sheets con snaps;
- `GestureDetector`/gestos semánticos para onboarding, mapa y hojas.

El modo `reduce motion` deshabilitará cámara 3D, wobble y animaciones
decorativas, conservando el cambio funcional de estado y una transición breve.

Sin proveedor de mapas, la superficie visual podrá conservar controles y
composición del prototipo, pero no pintará calles, vehículos, rutas ni ETA
ficticias en producción. El modo demo explícito podrá reproducir la escena
visual con una marca visible de datos de demostración.

## 7. Contrato API y comportamiento sin proveedor

El contrato canónico seguirá siendo `api/contracts/openapi.yaml`, bajo `/v1`.
Las capacidades publicadas son:

- salud y estado de proveedores;
- lugares y reverse geocoding;
- paradas, salidas y rutas;
- planificación y detalle de viajes;
- viajes activos;
- lugares guardados;
- rutinas;
- alertas y avisos;
- identidad, preferencias y privacidad;
- community reports post-MVP ya publicados para compatibilidad.

La implementación no agregará controller, estado de error, header o campo
sin actualizar contrato, ejemplo afectado y prueba de contrato.

Cuando una capacidad requiera una fuente ausente, la API devolverá la
respuesta canónica de `ProviderUnavailable` con `X-Trace-Id` y detalles
accionables, incluyendo `dataState: UNAVAILABLE` cuando aplique. Se
revisarán las operaciones de places que no explicitan `503` para que el
contrato refleje esta realidad. `LOCATION_OUT_OF_COVERAGE` será distinto de
`PROVIDER_UNAVAILABLE`.

La forma canónica de calidad será:

```text
DataQuality = freshness, dataState, liveVehicle, observedAt,
              providerDisplayName, sourceAuthorized
```

Los campos de fuente permanecerán nulos o falsos sin provider autorizado.
Los mappers rechazarán respuestas externas inválidas antes de que alcancen
el dominio.

## 8. Persistencia, identidad y privacidad

- `api/db/migrations/` es la fuente ejecutable del esquema.
- Prisma se usará para CRUD tipado; SQL explícito queda restringido a PostGIS,
  locking, concurrencia o consultas críticas justificadas.
- La ubicación precisa no se persiste por defecto; solo se conserva con el
  consentimiento y la política correspondiente.
- Lugares guardados son datos explícitos del usuario y respetan su política de
  consentimiento/retención.
- El modo invitado usa almacenamiento local seguro cuando aplique.
- La migración guest→cuenta es explícita, transaccional, idempotente y
  auditable.
- No se almacenan contraseñas; la identidad protegida depende del boundary
  JWT/OIDC definido por las specs.
- Las alertas, avisos, registros de dispositivos y operaciones sensibles
  soportan idempotencia donde el reintento móvil pueda duplicar acciones.
- Los jobs aplican retención de muestras de ubicación, datos de proveedor y
  métricas conforme a licencia y consentimiento.

## 9. Fixture y configuración de desarrollo

El modo demo será opt-in mediante configuración de ambiente. Sus límites son:

- adapters demo y fixtures viven detrás de puertos del gateway;
- ningún fixture se carga por defecto en producción;
- cada respuesta demo se marca `DEGRADED`, sin `LIVE` ni fuente autorizada;
- los nombres `RutaYa`, `Metrovia GTFS` y cifras del prototipo no se usan como
  identidad ni fuente productiva;
- la App podrá ejecutar un catálogo de estados para validar las 17 pantallas
  sin requerir red, pero ese catálogo no se mezclará con los repositorios de
  producción.

## 10. Plan de pruebas y aceptación

### 10.1 App

- análisis estático y formato Dart;
- unit tests de mapeo, estado, navegación y providers;
- widget tests de cada módulo en estados exitoso, vacío, error y recuperación;
- golden tests de las pantallas y composiciones visuales representativas en
  el viewport de referencia y en una ventana más ancha;
- pruebas de accesibilidad para Semantics, labels, switches, tabs y targets;
- integración del flujo primer inicio → onboarding → permisos → inicio →
  búsqueda → planificación → alternativas → viaje;
- prueba de `reduce motion` y de ausencia de provider.

### 10.2 API

- `typecheck`, build y lint existente;
- unit tests de casos de uso, errores, gateway, timeout y mappers;
- contract tests contra `openapi.yaml` y ejemplos;
- e2e con provider fake autorizado para capacidades de movilidad;
- e2e con providers deshabilitados que compruebe `UNAVAILABLE` y no datos
  inventados;
- pruebas de migraciones y verificación de esquema;
- pruebas de idempotencia, autorización, trace IDs y retención.

### 10.3 Workspace

Antes del cierre de cada corte:

```text
git diff --check
revisión de secretos y credenciales
revisión de referencias a RutaYa y datos demo
alineación spec ↔ contrato ↔ código ↔ pruebas
```

La definición de terminado global es:

1. 17 pantallas navegables y 9 estados representables.
2. Assets, transiciones, gestos y animaciones del prototipo implementados o
   documentados con una limitación técnica concreta.
3. App conectada al contrato `/v1` sin HTTP en widgets.
4. API compilable, modular y con respuestas honestas sin providers.
5. Fixtures exclusivamente de desarrollo/pruebas.
6. Migraciones verificables desde cero y desde la versión anterior.
7. Documentación, ADR, plan, contrato y trazabilidad actualizados.
8. Sin secretos, contraseñas ni ubicación precisa persistida sin consentimiento.

## 11. Riesgos y límites explícitos

| Riesgo | Mitigación |
|---|---|
| No existe provider autorizado | gateway con capacidad ausente, error canónico y fixture demo opt-in |
| Máxima fidelidad visual sin navegador companion | assets originales, análisis HTML/CSS/JS, golden tests y validación en viewport de referencia |
| HTML usa datos demo como parte de la composición | clasificación de contenido y separación estricta de fixtures |
| API fundacional aún no tiene todos los módulos | implementación por verticales con contrato primero |
| El cambio puede tocar mucho código de plantilla | preservar cambios del usuario, eliminar solo tras revisar referencias |
| La baseline y el HTML nombran variantes adicionales | `arrived` y `nocov` se modelan como estados, manteniendo 17 pantallas |

Quedan fuera de este diseño: elegir un proveedor comercial, adquirir
credenciales o licencias, introducir tiempo real WebSocket/SSE, convertir
community reports en alcance MVP o cambiar las rutas físicas del workspace.

## 12. Documentos que deberán mantenerse sincronizados

La implementación actualizará, cuando corresponda:

- `context/specs/` para comportamiento y criterios de aceptación;
- `context/adr/` para decisiones que alteren límites o políticas;
- `context/architecture/` para topología y responsabilidades;
- `api/contracts/openapi.yaml` y ejemplos;
- `api/db/migrations/` y `api/prisma/schema.prisma`;
- `context/architecture/traceability.md`;
- `context/plans/` y `docs/superpowers/plans/` para ejecución;
- `yegamo_app/README.md` y `api/README.md` para operación local.

Este documento es la base para el plan de implementación. No autoriza por sí
solo commits, pushes, adquisición de proveedores ni publicación de datos.
