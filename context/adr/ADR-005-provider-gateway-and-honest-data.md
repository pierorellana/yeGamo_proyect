# ADR-005: provider gateway y datos honestos

- **Estado:** accepted
- **Fecha:** 2026-10-02
- **Ámbito:** proveedores externos, fallback y calidad de datos

## Contexto

Horarios, rutas, lugares y posiciones tienen contratos, cobertura, licencias y
frescura distintas. El prototipo contiene datos demo y no puede definir la
disponibilidad productiva. El dominio necesita modelos canónicos y una forma
explícita de degradar sin presentar una estimación como tiempo real.

## Decisión

Se implementará un Provider Gateway con interfaces canónicas para
`TransitPlannerProvider`, `GeocodingProvider`, `VehiclePositionProvider` y
`TrafficIncidentProvider`. El gateway selecciona fuente, timeout, fallback,
circuit breaker, cache permitido por licencia, frescura y mapeo.

El backend normaliza exactamente estos estados: `CURRENT`, `STALE`,
`DEGRADED`, `OFFLINE_CACHE` y `UNAVAILABLE`. `LIVE` solo existe con fuente
autorizada y timestamp reciente; posiciones inferidas son `ESTIMATED`. El
cliente nunca calcula una ETA productiva ni eleva cache a `CURRENT`.

`DemoTransitProvider` se limita a desarrollo, pruebas y demos marcadas. Los
adapters productivos son configurables por ambiente y están sujetos a cobertura
y licencia. Si no hay fuente autorizada, el gateway devuelve `UNAVAILABLE` o
`DEGRADED`; nunca inventa horarios, rutas, ETA o posiciones ni filtra DTOs
propietarios.

## Alternativas consideradas

1. **Integración directa desde cada módulo:** descartada por acoplamiento a
   DTOs, licencias y errores externos.
2. **Proveedor demo como fuente productiva:** descartado por falta de garantía
   de cobertura y frescura.
3. **Proveedor único inmutable:** descartado por cobertura, resiliencia y
   expansión a otras ciudades.
4. **Booleano `isLive` o frescura decidida por Flutter:** descartado por no
   representar estados degradados y por permitir precisión falsa.

## Consecuencias

- El dominio y Flutter reciben modelos estables y estados explícitos.
- Fallback, timeout, licencias y salud se observan en una frontera única.
- Cada adapter necesita mappers, tests de contrato, límites y métricas.
- El diseño debe diferenciar `LIVE`/`ESTIMATED` por texto y forma, no solo color.

## Límites del MVP

- El primer alcance es Guayaquil.
- No se requiere GPS propio en buses ni WebSocket/SSE.
- Google Transit u otro adapter productivo queda condicionado a cobertura,
  licencia y configuración; este ADR no selecciona uno.
- Comunidad y ocupación no elevan por sí solas la calidad a `CURRENT`.

## Cómo se verifica

- Tests de mappers bloquean DTOs propietarios fuera del gateway.
- Tests de timeout, fallback y circuito cubren `DEGRADED` y `UNAVAILABLE`.
- Tests rechazan `LIVE` sin fuente autorizada y `observedAt` reciente.
- Contract y widget tests cubren los cinco estados de datos y su recuperación.
