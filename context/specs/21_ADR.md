# Architecture Decision Records - baseline

## ADR-001 Flutter para cliente movil
**Decision:** Flutter Android/iOS. **Razon:** una sola base, experiencia movil rica y capacidad de integrar APIs nativas.

## ADR-002 Node.js/TypeScript para backend
**Decision:** Node.js + TypeScript + NestJS. **Razon:** modularidad, velocidad de iteracion y buen encaje con APIs externas/realtime.

## ADR-003 PostgreSQL + PostGIS
**Decision:** PostGIS obligatorio. **Razon:** nearby, containment, distance, corredores y geometrias son dominio central.

## ADR-004 Provider Adapter
**Decision:** ninguna integracion de transporte se usa directamente desde UI/domain. **Razon:** disponibilidad/licencias/cobertura pueden cambiar.

## ADR-005 MVP sin dependencia de vehicle positions
**Decision:** el negocio principal funciona con planificacion/ETA sin mapa de bus live. **Razon:** no se encontro API oficial abierta de GPS de flota.

## ADR-006 Precision honesta
**Decision:** ETA es rango + confianza cuando corresponda. **Razon:** confianza del usuario es mas importante que falsa precision.

## ADR-007 yeGamo como identidad oficial
**Decision:** adoptar `yeGamo` como nombre oficial y deprecar `RutaYa` en producto, codigo visible y documentacion nueva. **Razon:** el prototipo y la identidad visual ya fueron actualizados.

## ADR-008 Prototipo como referencia UX, no como fuente de datos
**Decision:** el prototipo define flujos y presentacion, pero sus horarios, scores, lugares y nombres de proveedor se tratan como mock. **Razon:** evita convertir datos visuales de demostracion en supuestos de integracion.

## ADR-009 Rutinas y avisos dentro del MVP de producto
**Decision:** mantener las pantallas y capacidades basicas de Rutinas y Avisos en MVP. **Razon:** ya forman parte del flujo navegado y fortalecen el JTBD de anticipacion.
