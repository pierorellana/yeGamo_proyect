# Riesgos, supuestos y mitigaciones

## R1 - No existe API oficial abierta de buses
**Impacto:** alto. **Mitigacion:** provider abstraction, Google Transit para MVP, gestion paralela con ATM, GTFS discovery.

## R2 - Cobertura incompleta de Google Transit en Guayaquil
**Impacto:** alto. **Mitigacion:** spike temprano con rutas reales y matriz de cobertura antes de UX final.

## R3 - Costos por API
**Impacto:** medio/alto. **Mitigacion:** cuotas, backend proxy, caching permitido, limites, telemetria de costo.

## R4 - Restricciones de licencia
**Impacto:** alto. **Mitigacion:** storage policy por provider, no persistir resultados restringidos, revision legal antes de produccion.

## R5 - OSM incompleto/desactualizado
**Impacto:** medio. **Mitigacion:** complemento, no source of truth unico, validacion manual de zona piloto.

## R6 - Precision insuficiente
**Impacto:** alto sobre confianza. **Mitigacion:** rangos, score, medir error, no prometer exactitud falsa.

## R7 - Background location genera rechazo/privacidad/bateria
**Impacto:** medio. **Mitigacion:** MVP con foreground; permisos escalonados; actualizacion adaptativa.

## R8 - Falta de masa critica comunitaria
**Impacto:** medio. **Mitigacion:** comunidad no bloquea MVP; activar cuando exista base de usuarios.

## Supuestos
- Guayaquil es ciudad piloto.
- El usuario tiene conectividad durante planificacion en la mayoria de casos.
- Proveedor primario ofrece suficiente cobertura para demostrar el JTBD principal.
- yeGamo no operara ni controlara buses; es una capa de informacion/planificacion.

## R9 - Confundir datos mock del prototipo con integraciones reales
**Impacto:** alto sobre confianza. **Mitigacion:** fuente visible controlada por backend, feature flags, ambientes con datos de demostracion claramente marcados y pruebas que bloqueen nombres mock en produccion.
