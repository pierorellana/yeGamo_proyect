# C-002: detalle de persistencia SQL-first con Prisma Client y `pg`

- **Estado:** accepted
- **Fecha:** 2026-10-02
- **Tipo:** complementaria
- **ADR canónico relacionado:** [ADR-004](ADR-004-sql-first-migrations-and-data-access.md)
- **Ámbito:** PostgreSQL/PostGIS, migraciones y repositorios del API

## Contexto

El dominio necesita relaciones transaccionales, restricciones de integridad,
consultas espaciales y operaciones concurrentes para viajes, alertas y
catálogo de transporte. El esquema debe poder reproducirse desde una base
vacía y evolucionar mediante cambios revisables. Un ORM como única fuente de
verdad ocultaría parte de las decisiones de PostgreSQL/PostGIS y no expresa de
forma uniforme todas las operaciones geoespaciales o de locking.

## Decisión

PostgreSQL + PostGIS será la persistencia primaria y el **SQL versionado será
la fuente de verdad del esquema**. Las migraciones serán deterministas,
ordenadas y ejecutables desde una base vacía y desde una versión anterior.
Usarán UUID, `timestamptz`, `geography(Point,4326)` para ubicaciones y
`geometry(LineString,4326)` para shapes, con índices, checks, claves foráneas y
políticas `ON DELETE` explícitas.

Los repositorios CRUD usarán **Prisma Client** para acceso tipado y composición
de dependencias. Se permite SQL crudo mediante **`pg`** únicamente cuando la
operación requiera PostGIS, locking o concurrencia que Prisma no pueda
expresar adecuadamente. Cada uso de `pg` debe conservar una justificación
local junto al repositorio o consulta, además de parámetros enlazados y tests.

La capa de dominio no conoce Prisma ni `pg`; interfaces de repositorio y casos
de uso separan las reglas del acceso a datos.

## Alternativas consideradas

1. **Prisma como fuente exclusiva del esquema:** descartado; reduce el control
   explícito sobre PostGIS, índices, checks y migraciones SQL.
2. **SQL crudo para todo:** descartado; aumenta el código repetitivo y pierde
   beneficios del acceso tipado en CRUD ordinario.
3. **MongoDB u otra base documental:** descartado; el dominio necesita
   integridad relacional, consultas espaciales y transacciones.
4. **Migraciones automáticas derivadas del modelo:** descartado como fuente
   canónica; dificulta revisar cambios operativos y reproducir PostGIS.

## Consecuencias

Positivas:

- El esquema y sus restricciones son auditables y reproducibles.
- Prisma reduce errores en CRUD y mantiene tipos cerca del código.
- PostGIS permite búsquedas de cercanía y shapes con índices espaciales.
- La política explícita de `pg` evita que SQL crudo se vuelva el acceso por
  defecto.

Costos y obligaciones:

- Hay que mantener migraciones, modelo Prisma y repositorios sincronizados.
- Las migraciones requieren pruebas contra PostgreSQL/PostGIS real.
- Las consultas de concurrencia necesitan revisión, parámetros y pruebas de
  aislamiento; no basta con validar tipos en compilación.

## Límites del MVP

- No se introduce una segunda base de datos como fuente operativa.
- Cache, circuit breakers y estado temporal se abstraen para escalar después,
  pero no justifican una plataforma distribuida en el MVP.
- La ubicación precisa no se persiste por defecto; las observaciones que la
  necesiten tienen consentimiento y retención corta.

## Cómo se verifica

- Un runner aplica todas las migraciones en orden y registra la versión.
- CI ejecuta migraciones desde cero y desde una versión anterior contra
  PostgreSQL/PostGIS.
- Cada uso de `pg` incluye una justificación, parámetros enlazados y un test de
  comportamiento o concurrencia.
- Los tests de repositorio verifican constraints, índices relevantes y
  transacciones de operaciones idempotentes.
