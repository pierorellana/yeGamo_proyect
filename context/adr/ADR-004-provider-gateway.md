# C-004: detalle del gateway canónico de proveedores

- **Estado:** accepted
- **Fecha:** 2026-10-02
- **Tipo:** complementaria
- **ADR canónico relacionado:** [ADR-005](ADR-005-provider-gateway-and-honest-data.md)
- **Ámbito:** transporte, geocodificación, posiciones, incidentes y fuentes

## Contexto

La planificación depende de horarios, geometrías, lugares y, cuando exista,
posición de vehículos. Las fuentes externas tienen contratos, licencias,
latencias y niveles de frescura distintos. El prototipo contiene datos demo,
incluyendo `RutaYa`, `Metrovia GTFS`, horarios y scores, que no pueden ser
tratados como disponibilidad productiva.

El dominio debe poder cambiar de proveedor, combinar fuentes y degradar la
respuesta sin filtrar DTOs propietarios ni afirmar una precisión que la fuente
no respalda.

## Decisión

Se implementará un **Provider Gateway** con interfaces canónicas para
`TransitPlannerProvider`, `GeocodingProvider`, `VehiclePositionProvider` y
`TrafficIncidentProvider`. El gateway selecciona proveedor primario/secundario,
timeouts, circuit breaker, cache permitido por licencia, frescura, `dataState`
y mapeo a modelos canónicos.

`DemoTransitProvider` existe únicamente en desarrollo, pruebas y ambientes de
demostración marcados. Los adapters productivos se habilitan por configuración
y feature flag, sujetos a cobertura, licencia, límites y salud de la fuente.
El API nunca expone DTOs propietarios ni usa nombres demo como fuente
productiva; el cliente recibe un modelo canónico con `providerDisplayName`
controlado por backend.

Cuando no exista una fuente autorizada, el gateway devuelve `UNAVAILABLE` o
`DEGRADED`; no inventa rutas, horarios, ETA ni posiciones.

## Alternativas consideradas

1. **Integrar directamente cada proveedor desde los módulos de dominio:**
   descartado; acopla reglas, DTOs, licencias y manejo de errores.
2. **Usar solo el proveedor demo:** descartado; sirve para pruebas, no para
   afirmar cobertura o disponibilidad reales.
3. **Elegir un proveedor único e inmutable:** descartado; limita cobertura,
   resiliencia y capacidad de cambiar por ciudad o licencia.
4. **Publicar DTOs externos en Flutter:** descartado; convierte contratos de
   terceros en contratos de producto y dificulta la evolución.

## Consecuencias

Positivas:

- El dominio conserva modelos estables y testeables.
- Fallback, timeout y circuit breaker tienen un lugar único.
- Se puede incorporar otra ciudad o adapter sin reescribir Flutter.
- La licencia y la frescura se consideran parte del resultado, no metadatos
  olvidados.

Costos y obligaciones:

- Cada adapter necesita mappers, tests de contrato y observabilidad.
- El gateway requiere configuración segura, límites de uso y métricas de salud.
- Los equipos deben mantener una matriz de cobertura/licencia por proveedor.

## Límites del MVP

- El primer alcance es Guayaquil.
- El proveedor demo queda restringido a desarrollo, pruebas y demos marcadas.
- No se requiere GPS propio instalado en buses ni streaming WebSocket/SSE.
- Un adapter como Google Transit es una posibilidad condicionada a cobertura,
  licencia y configuración; no es una decisión productiva de este ADR.

## Cómo se verifica

- Tests de mappers prueban que ningún DTO de proveedor cruza la frontera.
- Tests de timeout, fallback y circuito verifican `DEGRADED`/`UNAVAILABLE`.
- Un test de configuración impide activar `DemoTransitProvider` como fuente
  productiva.
- Contract tests verifican que el API solo publica esquemas canónicos y que
  `LIVE` requiere fuente autorizada y timestamp reciente.
