# ADR-004: migraciones y acceso SQL-first

- **Estado:** accepted
- **Fecha:** 2026-10-02
- **Ámbito:** PostgreSQL/PostGIS, migraciones y repositorios

## Contexto

yeGamo necesita relaciones transaccionales, integridad referencial, búsquedas
espaciales y control explícito de concurrencia. El esquema debe reproducirse
desde cero y actualizarse desde versiones anteriores con cambios auditables.

## Decisión

PostgreSQL + PostGIS será la persistencia primaria y el SQL versionado será la
fuente de verdad. Las migraciones deterministas vivirán en
`api/db/migrations/`, usarán UUID, `timestamptz`, `geography(Point,4326)` y
`geometry(LineString,4326)`, además de checks, FKs, `ON DELETE` explícito e
índices B-tree/GiST.

Prisma Client será el acceso tipado por defecto para CRUD y repositorios.
`pg` crudo se reservará para PostGIS, locking o concurrencia que Prisma no
pueda expresar; cada uso llevará justificación local, parámetros enlazados y
pruebas. El dominio no importará Prisma ni `pg`.

## Alternativas consideradas

1. **Prisma como fuente exclusiva:** descartado por el control insuficiente de
   PostGIS, índices y constraints operativas.
2. **SQL crudo para todo:** descartado por repetición y pérdida de tipos en CRUD.
3. **Base documental:** descartada por relaciones, transacciones y geoespacial.
4. **Migraciones derivadas automáticamente:** descartadas como fuente canónica
   por menor auditabilidad.

## Consecuencias

- El esquema es revisable, reproducible y portable entre ambientes.
- Prisma simplifica CRUD; `pg` mantiene una excepción controlada para casos
  especializados.
- Se deben mantener sincronizados SQL, Prisma y repositorios.
- Las migraciones y concurrencia requieren PostgreSQL/PostGIS real en pruebas.

## Límites del MVP

- No se incorpora una segunda base de datos operativa.
- Cache y estado temporal se abstraen, pero no requieren infraestructura
  distribuida.
- Las observaciones de ubicación precisas requieren consentimiento y retención
  corta.

## Cómo se verifica

- El runner aplica migraciones desde base vacía y desde una versión anterior.
- CI ejecuta tests contra PostgreSQL/PostGIS real.
- Cada consulta `pg` se revisa por justificación, parámetros e aislamiento.
