# yeGamo API

El API de yeGamo será un monolito modular NestJS con REST/JSON versionado bajo
`/v1`. Esta superficie contiene el contrato HTTP y, en las siguientes fases,
los módulos de aplicación, el worker y las migraciones SQL.

## Contrato y límites

- El contrato canónico es [`contracts/openapi.yaml`](contracts/openapi.yaml).
- Las reglas funcionales provienen de [`../context/specs/11_API_SPEC.md`](../context/specs/11_API_SPEC.md).
- Las respuestas exponen modelos canónicos; nunca exponen DTOs propietarios de
  proveedores.
- `LIVE` solo se puede publicar con una fuente autorizada, `observedAt` y
  frescura suficiente. El backend decide `dataState` y calidad.
- El API no almacena contraseñas ni persiste ubicación precisa sin consentimiento.
- Los datos de demostración del prototipo no son fuentes productivas.

## Verificación local

Desde `api/` y con Node.js `>=20`:

```bash
npm ci
npm run typecheck
npm run build
npm test -- --runInBand --watchman=false
npm run db:verify
```

`npm run db:verify` necesita un `DATABASE_URL` apuntando a PostgreSQL con
PostGIS y `pgcrypto`. Sin esa variable el comando debe fallar explícitamente;
no se considera un pase simulado. La suite de migraciones también queda
omitida por Jest cuando no existe esa precondición.

## Datos demo y proveedores

No hay proveedor autorizado de transporte o geocodificación configurado. En
producción las capacidades dependientes responden `503
PROVIDER_UNAVAILABLE`, `dataState: UNAVAILABLE` y `X-Trace-Id`. El adapter
`DemoTransitProvider` sólo se puede activar de forma explícita fuera de
producción:

```bash
NODE_ENV=development DEMO_PROVIDER_ENABLED=true npm run start:dev
```

No usar esa bandera como configuración productiva ni presentar sus respuestas
como `LIVE`.

## Organización

```text
api/
├── contracts/       # frontera HTTP versionada y ejemplos
├── db/migrations/   # fuente de verdad SQL en el plan de datos
├── src/              # monolito modular NestJS
└── test/             # pruebas unitarias, integración y contrato
```

La implementación no debe agregar un controller, estado de error o header sin
actualizar primero el contrato, el ejemplo afectado y la prueba de contrato en
la misma corrida. El inventario ejecutable está en
`test/contracts/openapi-contract.spec.ts`; las capacidades de comunidad
publicadas para compatibilidad están marcadas `post-mvp` y no se cuentan como
runtime implementado.
