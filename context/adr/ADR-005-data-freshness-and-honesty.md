# C-005: detalle de estados de frescura y honestidad de datos

- **Estado:** accepted
- **Fecha:** 2026-10-02
- **Tipo:** complementaria
- **ADR canónico relacionado:** [ADR-005](ADR-005-provider-gateway-and-honest-data.md)
- **Ámbito:** calidad del API, respuestas de transporte y estados UX

## Contexto

Las llegadas son estimaciones y pueden quedar obsoletas, degradarse por una
fuente parcial o no existir por falta de cobertura. El prototipo muestra
estados visuales de éxito, carga, vacío, error, offline, stale, degraded,
permisos y sin cobertura. Es necesario distinguir la calidad del dato de la
apariencia de la pantalla para evitar que un cache o una posición inferida se
presente como tiempo real.

## Decisión

El backend normaliza la calidad a exactamente estos estados de datos:

- `CURRENT`: resultado reciente de una fuente autorizada.
- `STALE`: resultado conocido cuya frescura superó el umbral aplicable.
- `DEGRADED`: resultado parcial, fallback o con calidad reducida.
- `OFFLINE_CACHE`: resultado local/cacheado sin consulta actual confirmada.
- `UNAVAILABLE`: no hay resultado confiable para responder.

La UI mapea esos estados a los nueve estados UX del producto y comunica
frescura, limitaciones y acciones de recuperación. `LIVE` solo se permite con
fuente autorizada y timestamp reciente; una posición inferida se marca
`ESTIMATED`. El backend decide nombres de fuente, timestamps de observación,
calidad y copy de confiabilidad. El cliente no calcula una ETA productiva ni
promueve `OFFLINE_CACHE` a `CURRENT`.

Los timeouts intentan fallback dentro de límites definidos. Sin fallback se
devuelve un error recuperable con `traceId`. Un cambio relevante en la
recomendación conserva una causa disponible para explicar la diferencia.

## Alternativas consideradas

1. **Un booleano `isLive`:** descartado; no representa stale, fallback, cache ni
   ausencia de datos.
2. **Dejar que Flutter deduzca la frescura:** descartado; distribuye reglas y
   puede mostrar precisión falsa.
3. **Ocultar errores y mostrar el último dato:** descartado; confunde cache con
   información actual y daña la confianza.
4. **Inventar ETA cuando falta proveedor:** descartado; una estimación sin base
   autorizada es peor que un estado no disponible.

## Consecuencias

Positivas:

- API y Flutter comparten un vocabulario explícito de calidad.
- Los datos antiguos siguen siendo útiles si se etiquetan correctamente.
- Observabilidad puede correlacionar fuente, fallback, latencia, estado y error.
- Las pruebas pueden bloquear `LIVE` sin fuente o timestamp reciente.

Costos y obligaciones:

- Cada respuesta de planificación debe transportar calidad suficiente para su
  presentación.
- Hay que definir umbrales de frescura por tipo de fuente y documentarlos.
- El diseño visual debe diferenciar `LIVE`/`ESTIMATED` por texto y forma, no
  solo por color.

## Límites del MVP

- Los estados se aplican a planificación, cercanía, llegadas y viajes según
  disponibilidad del contrato; no se construye un sistema de streaming.
- El cache offline de invitado no es una fuente de ETA actual.
- Comunidad, ocupación y observaciones avanzadas son post-MVP y no pueden
  elevar por sí solas la calidad a `CURRENT`.

## Cómo se verifica

- Contract tests validan el enum de estados y los campos de frescura.
- Tests de gateway cubren fuente reciente, stale, timeout, fallback y ausencia.
- Un test rechaza cualquier payload `LIVE` sin `provider` autorizado y
  `observedAt` reciente.
- Widget/integration tests verifican los nueve estados UX y su recuperación sin
  convertir cache o datos estimados en actuales.
