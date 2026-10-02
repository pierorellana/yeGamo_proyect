# ADR-002: API modular NestJS como monolito modular

- **Estado:** accepted
- **Fecha:** 2026-10-02
- **Ámbito:** API REST/JSON, módulos de dominio y worker

## Contexto

El API debe centralizar autorización, planificación, ranking, confiabilidad,
calidad de datos y persistencia. El MVP necesita iterar sobre estas reglas sin
asumir el costo operativo de muchos despliegues independientes, pero debe dejar
límites que permitan extraer una capacidad si el crecimiento lo exige.

## Decisión

Se usará NestJS + TypeScript como **monolito modular**. Los módulos se agrupan
por dominio: identidad, usuarios, preferencias, lugares, tránsito,
planificación, viajes activos, rutinas, alertas, notificaciones, privacidad y
confiabilidad.

Cada módulo separa, según necesidad, `domain`, `application`,
`infrastructure` y `presentation`. El dominio y los casos de uso no importan
NestJS, Prisma, `pg` ni DTOs de proveedores. El pipeline HTTP será
trace → auth → validación → controller → caso de uso → dominio → repositorio o
gateway → mapper canónico → respuesta.

El worker será un proceso separado que comparte el mismo código para alertas,
notificaciones, retención, métricas y refresco de feeds autorizados. Las
peticiones HTTP serán stateless y el contrato será REST/JSON bajo `/v1`.

## Alternativas consideradas

1. **Microservicios desde el inicio:** descartado por costo operativo y falta de
   necesidad del MVP.
2. **Monolito sin límites:** descartado porque acoplaría dominio, framework y
   proveedores.
3. **Serverless por endpoint:** descartado para el baseline por jobs,
   conexiones de base y operaciones idempotentes.

## Consecuencias

- Un despliegue inicial simplifica operación y transacciones.
- Los límites por dominio permiten pruebas y extracción futura.
- API y worker comparten reglas, mappers y observabilidad.
- Se necesita disciplina para controlar dependencias entre módulos.

## Límites del MVP

- No se crean microservicios independientes.
- No se requiere WebSocket/SSE.
- El primer alcance operativo es Guayaquil; comunidad y ocupación no son
  requisitos de lanzamiento.

## Cómo se verifica

- El análisis de imports bloquea dependencias de infraestructura desde dominio.
- Tests de contrato validan `/v1`; integración cubre autorización, jobs,
  idempotencia y persistencia.
- Cualquier extracción a microservicio o canal de tiempo real requiere un ADR
  de cambio con evidencia operativa.
