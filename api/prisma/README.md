# Prisma como artefacto derivado

Las migraciones SQL de `api/db/migrations/` son la única fuente de verdad del
esquema. `api/prisma/schema.prisma` existe para generar un cliente tipado para
CRUD después de aplicar el SQL; no se deben crear migraciones con
`prisma migrate` ni editar el esquema Prisma para cambiar la base.

Los campos espaciales se mantienen en SQL como `geography(Point,4326)` y
`geometry(LineString,4326)`. Prisma no serializa estos tipos de extensión, por
lo que aparecen como `Unsupported(...)` y las consultas PostGIS deben vivir en
repositorios/adapters explícitos que usen `pg`, con parámetros enlazados y una
justificación de la necesidad espacial.

Flujo esperado:

1. Aplicar `api/db/migrations` con el runner transaccional.
2. Verificar con `npm run db:verify` cuando exista el bootstrap del API.
3. Ejecutar `prisma generate` contra este archivo para los modelos CRUD.
4. Validar que cualquier cambio de SQL también actualice este artefacto
   derivado y su prueba de esquema.

Los seeds no se ejecutan desde Prisma y requieren explícitamente
`yegamo.seed_mode=development`.
