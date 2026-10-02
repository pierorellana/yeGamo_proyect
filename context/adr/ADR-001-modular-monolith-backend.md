# C-001: detalle del backend modular monolith

- **Estado:** accepted
- **Fecha:** 2026-10-02
- **Tipo:** complementaria
- **ADR canónico relacionado:** [ADR-002](ADR-002-modular-nestjs-api.md)
- **Ámbito:** API NestJS, worker y límites del dominio

## Contexto

yeGamo necesita exponer planificación, lugares, transporte, viajes activos,
rutinas, avisos, privacidad y confiabilidad. El producto debe crecer a más
usuarios y ciudades, pero el MVP todavía necesita iterar rápido sobre reglas
de planificación y calidad de datos. Separar cada capacidad como un servicio
desde el inicio añadiría despliegues, contratos operativos y fallos de red que
no están justificados por el volumen actual.

Las reglas de negocio no deben quedar acopladas a NestJS ni a un proveedor
externo. El API debe ser stateless en las peticiones HTTP y el trabajo
programado debe poder ejecutarse fuera de la petición.

## Decisión

Construiremos el backend como un **monolito modular NestJS + TypeScript** en un
único proceso de API y un proceso worker que comparte el mismo código y
composición de módulos.

Los módulos se organizan por dominio (`auth`, `users`, `preferences`, `places`,
`transit`, `journey-planning`, `active-journeys`, `commute-profiles`,
`leave-alerts`, `notifications`, `privacy` y `reliability`). Cada módulo puede
tener `domain`, `application`, `infrastructure` y `presentation`. El núcleo de
planificación, ranking, confiabilidad y gateway no importa NestJS, Prisma, `pg`
ni DTOs de un proveedor.

Los controllers validan y traducen HTTP; los casos de uso coordinan; el dominio
decide; los repositorios y gateways ejecutan efectos externos. El worker
evalúa alertas, notificaciones, expiraciones, retención, métricas y refrescos
de feeds cuando estén autorizados.

## Alternativas consideradas

1. **Microservicios desde el inicio:** descartado; aumenta el costo operativo y
   la complejidad de coordinación sin una necesidad del MVP.
2. **Monolito sin límites internos:** descartado; permitiría que widgets,
   controllers y persistencia compartieran reglas y haría costosa una futura
   extracción.
3. **Serverless por endpoint:** descartado para el baseline; complica jobs,
   conexiones de PostgreSQL y consistencia de operaciones idempotentes.

## Consecuencias

Positivas:

- Un despliegue y una transacción local simplifican el MVP.
- Los límites por dominio permiten probar y extraer módulos en el futuro.
- API y worker reutilizan reglas, mappers y observabilidad.
- Los contratos HTTP y los eventos internos pueden evolucionar sin exponer
  detalles de infraestructura al dominio.

Costos y obligaciones:

- El repositorio requiere disciplina de dependencias entre módulos.
- El proceso worker necesita operación, reintentos y métricas propias.
- El monolito será una unidad de despliegue hasta que una extracción esté
  justificada por volumen, aislamiento o propiedad operativa.

## Límites del MVP

- No se crean microservicios independientes.
- No se implementan WebSocket ni SSE; REST/JSON bajo `/v1` es suficiente.
- No se instala GPS propio en buses ni se convierte comunidad/ocupación en
  requisito de lanzamiento.

## Cómo se verifica

- Las dependencias de dominio no importan NestJS, Prisma, `pg` ni adapters de
  proveedores.
- Los módulos se registran mediante composición NestJS y el worker comparte
  casos de uso sin duplicarlos.
- Los tests de contrato cubren `/v1` y los tests de integración cubren jobs,
  idempotencia y límites de persistencia.
- Una revisión arquitectónica bloquea nuevos microservicios o canales de
  tiempo real sin un ADR de cambio.
