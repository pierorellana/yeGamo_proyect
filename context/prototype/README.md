# Prototipo yeGamo

## Propósito y autoridad

`yeGamo Prototype.html` es la referencia de flujo y de jerarquía visual para
la implementación móvil. Sirve para validar la secuencia de navegación, las
17 pantallas, los nueve estados UX y la composición de los componentes; no es
un contrato de datos ni una fuente productiva.

La precedencia de implementación es:

1. `context/specs/` para comportamiento, requisitos y contratos.
2. `context/adr/` y el diseño aprobado para decisiones técnicas.
3. Este directorio y el HTML para flujo, look and feel y nomenclatura visual.
4. `api/contracts/openapi.yaml` y `api/db/migrations/` para las superficies
   ejecutables del backend.

## Límite de los datos del prototipo

Los horarios, ETA, scores de fiabilidad, tamaños de muestra, lugares de
Guayaquil, nombres de fuente, disponibilidad, textos como `Metrovia GTFS` y
cualquier cifra mostrada en el HTML son datos de demostración o fixtures
visuales. No deben convertirse en defaults de negocio, fixtures productivos,
fuentes autorizadas ni disponibilidad real.

En producción:

- la fuente visible, su frescura, calidad y `dataState` vienen del API;
- `LIVE` solo se muestra con una fuente autorizada y timestamp reciente;
- una respuesta sin proveedor confiable se muestra como `DEGRADED`, `STALE`,
  `UNAVAILABLE` u otro estado canónico, sin inventar ETA;
- `RutaYa` es una etiqueta histórica interna del artefacto y no puede aparecer
  como marca de la app; la identidad oficial es `yeGamo`;
- si no existe una fuente verificada, se usa copy genérico como
  `Datos de transporte actualizados hace X min`.

## Baseline visual y de flujo

La baseline conserva exactamente 17 pantallas, incluida `Cargando`, y los
estados `ok`, `loading`, `empty`, `error`, `offline`, `stale`, `degraded`,
`permission` y `nocoverage`. La matriz completa está en
[`screens/yeGamo-mobile.md`](screens/yeGamo-mobile.md); los tokens están en
[`DESIGN-TOKENS.md`](DESIGN-TOKENS.md).

El HTML puede mostrar más de una variante de una pantalla mediante sus
controles de estado. Esas variantes no aumentan el conteo de pantallas: se
implementan como estados del módulo Flutter correspondiente.

## Regla para implementar

Antes de copiar un texto o dato del HTML, clasificarlo como estructura visual,
copy de interacción o dato simulado. Solo los dos primeros pueden pasar al
cliente sin una decisión adicional; cualquier dato simulado debe reemplazarse
por el modelo canónico del API o por un fixture de desarrollo explícitamente
marcado.
