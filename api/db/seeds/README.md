# Seeds de desarrollo

`development.sql` contiene únicamente un catálogo sintético marcado con
`is_demo = true` y referencias con `storage_policy = 'EPHEMERAL_ONLY'`. El
runner de migraciones nunca ejecuta seeds automáticamente.

Para ejecutarlo hay que activar el modo explícito en la misma sesión de
PostgreSQL:

```bash
PGOPTIONS='-c yegamo.seed_mode=development' \
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f api/db/seeds/development.sql
```

No se deben ejecutar estos datos en producción. El SQL falla si la sesión no
declara `yegamo.seed_mode=development`; tampoco contiene nombres de fuentes o
feeds del prototipo.
