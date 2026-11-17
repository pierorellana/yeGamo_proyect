# ADR-010: fuente de datos de transporte público para Guayaquil

- **Estado:** accepted
- **Fecha:** 2026-11-17
- **Ámbito:** proveedor de transporte, licencias, cobertura y límites honestos
- **Relacionados:** [ADR-005](ADR-005-provider-gateway-and-honest-data.md), [ADR-008](ADR-008-providerless-mvp-and-prototype-fixtures.md)

## Contexto

El MVP debía sustituir el proveedor demo por datos reales y gratuitos. Antes de
integrar nada se investigó (consulta del 2026-11-17, con evidencia y consultas
propias a Overpass) qué existe realmente para Guayaquil. No se asumió cobertura
por el hecho de que un proveedor opere en otras ciudades.

## Evidencia

| Fuente | Cobertura Guayaquil | Rutas | Paradas | Horarios / salidas | ETA / tiempo real | Licencia y costo |
|---|---|---|---|---|---|---|
| **OpenStreetMap** (Overpass / extractos) | Metrovía buena; buses urbanos casi nula | Trazado sí (84 relaciones `route=bus` en 25 km; 73 son Metrovía) | Parcial: 535 `bus_stop` + 266 `platform`; solo 33/84 relaciones con ≥2 paradas miembro | **No** (0 `opening_hours`, 0 `interval`) | **No** | ODbL, gratis; Overpass pública con límites de uso |
| GTFS / Mobility Database / Transitland | No se encontró feed de Guayaquil ni de Ecuador (APIs no consultables: «no encontrado», no «inexistente») | — | — | — | — | — |
| datosabiertos.gob.ec | 0 resultados para «guayaquil transporte» | — | — | — | — | — |
| ATM / Municipio / Metrovía | Solo PDFs (reportes de la Aerovía, boletines) | No estructurado | No | Horario de la Aerovía en prensa, no en feed | No | Sin licencia de reutilización definida |
| Google Maps / Moovit | Alta (109 rutas y 3.129 paradas según Google, 2020) | Sí | Sí | Frecuencias (Google) | Solo dentro de sus apps | Propietario; ToS prohíben extracción. **No se usa ni se hace scraping.** |
| GTFS-Realtime | No existe feed público; BRTData lista «real time: None» para la Metrovía | — | — | — | — | — |

## Decisión

1. **Única fuente real y legal hoy: OpenStreetMap.** Se usa para descubrir
   paradas y trazados (adaptadores `overpass-transit` y `openstreetmap-map-transit`
   ya integrados tras el gateway, con timeout, múltiples endpoints y caché en
   memoria). Atribución obligatoria «© OpenStreetMap contributors».
2. **No existe fuente abierta de horarios, salidas programadas, ETA ni tiempo
   real.** Por tanto el API **no** los produce: `eta` es siempre `null`,
   `liveVehicle` es siempre `false` y no hay vehículos en vivo.
3. **`POST /v1/journeys/plan` no tiene proveedor de planificación real.** Sin
   horarios no se puede calcular una duración de viaje en transporte público sin
   inventarla, así que en producción responde `503 PROVIDER_UNAVAILABLE`
   (`dataState: UNAVAILABLE`) en lugar de un plan simulado. El único planificador
   registrado es `DemoTransitProvider`, activo solo con `DEMO_PROVIDER_ENABLED=true`
   fuera de producción, marcado `DEGRADED`, sin fuente autorizada y con tramos a pie
   rotulados como «fixture de desarrollo».
4. **Cobertura prometida al usuario:** solo paradas y trazados cercanos
   (Metrovía mejor mapeada). Los buses urbanos convencionales no se pueden cubrir
   con datos abiertos.

## Licencia (ODbL)

Servir resultados y mapas es «Produced Work» (requiere atribución). Si se importa
OSM a PostgreSQL y se **distribuye** la base derivada, esa base queda bajo ODbL
(share-alike); por eso los datos OSM importados deben vivir en tablas separadas
de cualquier dato propio. No es asesoría legal; confirmar antes de exponer
extractos descargables.

## Consecuencias y siguientes pasos

- Para ofrecer planificación real hace falta una fuente con horarios: solicitar
  formalmente a la ATM un GTFS (o licencia) o mantener datos propios etiquetados
  como «referencia». Cuando exista, se implementa un `TransitPlannerProvider`
  nuevo tras el gateway y se retira el demo; no se requieren cambios de contrato.
- Mejorar OSM (paradas como miembros de relaciones, `interval`) es la vía abierta
  y sostenible para mejorar la cobertura.
- Riesgo operativo: el Overpass público devolvió 502 «at capacity»; para
  producción conviene servidor propio o extracto Geofabrik con refresco programado.
- Limitaciones de la investigación: no se pudieron consultar las APIs de
  Transitland/Mobility Database; Aerovía no se verificó en Overpass; los conteos
  son de una sola corrida.
