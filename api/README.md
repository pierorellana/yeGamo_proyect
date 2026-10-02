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

## Organización prevista

```text
api/
├── contracts/       # frontera HTTP versionada y ejemplos
├── db/migrations/   # fuente de verdad SQL en el plan de datos
├── src/              # monolito modular NestJS
└── test/             # pruebas unitarias, integración y contrato
```

La implementación no debe agregar un controller, estado de error o header sin
actualizar primero el contrato, el ejemplo afectado y la prueba de contrato.
