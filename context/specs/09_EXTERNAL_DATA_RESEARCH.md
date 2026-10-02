# Investigacion de fuentes externas de movilidad

**Fecha de investigacion:** 19 de septiembre de 2026

## Hallazgo principal

La ATM declara en su portal de movilidad que el sistema de buses urbanos permite consultar rutas, recorridos, buses disponibles e informacion en tiempo real. Sin embargo, en la investigacion publica realizada **no se localizo documentacion de una API oficial abierta para desarrolladores, ni un feed GTFS/GTFS-Realtime de Guayaquil claramente publicado e indexado**. Por tanto, yeGamo no debe asumir acceso directo al GPS de la flota en el MVP.

## Evaluacion de fuentes

| Fuente | Que aporta | Acceso | Uso recomendado |
|---|---|---|---|
| ATM Guayaquil | Fuente institucional; rutas/estado y posible realtime en sus canales | Sitio publico; API dev no encontrada | Prioridad para convenio/solicitud de datos y validacion |
| Google Routes API | Transit routing, paradas, lineas, llegada/salida, polilineas, caminata | API key + billing | **Proveedor inicial de planificacion**, si se valida cobertura de Guayaquil |
| OpenStreetMap + Overpass | Paradas, relaciones de rutas y geometria mapeada | Publico con politicas de uso | Complemento/fallback y enriquecimiento; no asumir completitud |
| Transitland | Catalogo y REST de GTFS/GTFS-RT | API key; free tier limitado | Descubrir/consumir feeds si Guayaquil aparece o se registra |
| Mobility Database | Catalogo global GTFS/GTFS-RT | OAuth2 | Descubrimiento y descarga de datasets permitidos |
| Moovit | Datos de transporte y realtime; Guayaquil disponible en app/web | Licencia + API key + HMAC | Candidato fuerte **si se obtiene acuerdo comercial** |
| Waze for Cities | Jams, alertas, irregularidades | Solo partners | Integracion futura con ATM/Municipio/entidad elegible |
| Nominatim publico | Geocoding OSM | Publico y muy limitado | Solo prototipo/moderado; no autocomplete en produccion |

## Sobre Guayaquil

- El portal ATM afirma que existen capacidades de informacion en tiempo real para buses urbanos.
- El Municipio anuncio en 2026 un Plan Maestro para un Sistema Inteligente de Transporte Publico con operacion inteligente y centro de control, cuyos resultados estaban previstos para finales de 2026. Esto abre una oportunidad para que futuras fuentes oficiales cambien durante el proyecto.
- Moovit mantiene cobertura de Guayaquil en su producto de consumo, pero su API no es abierta: requiere credenciales/licencia.
- OpenStreetMap contiene al menos parte de las paradas/objetos de transporte de Guayaquil, pero su naturaleza comunitaria impide tratarlo como inventario oficial completo.

## Recomendacion concreta para el MVP

1. Crear un `TransitProviderAdapter` desde el primer sprint.
2. Implementar primero un adaptador Google Transit para validar la propuesta de negocio sin esperar convenio institucional.
3. Implementar OSM/Overpass como fuente complementaria para geometria/paradas donde sea util y legalmente compatible.
4. Crear jobs de descubrimiento para Transitland/Mobility Database, pero no bloquear el MVP si no hay feed local.
5. Abrir paralelamente una gestion con ATM solicitando GTFS/GTFS-RT, API o mecanismo oficial de acceso a rutas, horarios y posiciones.
6. Evaluar Moovit solo si el costo/licencia tiene sentido.
7. No hacer scraping de sitios o apps como fuente operacional del producto.

## Limitacion clave

Google Transit puede resolver itinerarios, pero no equivale a disponer del GPS crudo de cada bus. La visualizacion "bus moviendose en el mapa" requiere una fuente de `vehicle_positions`/GPS o un acuerdo con el operador. Si solo tenemos horarios/ETA, la app debe mostrar una estimacion y no un bus "en vivo".
