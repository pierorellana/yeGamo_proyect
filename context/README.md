# Contexto operativo de yeGamo

Este directorio contiene la documentación canónica que guía el desarrollo SDD del workspace. La implementación debe seguir la secuencia `spec → diseño/ADR → plan → implementación → pruebas → revisión → cierre`.

## Precedencia

- `specs/`: comportamiento, requisitos, modelo de dominio, criterios de aceptación y contratos funcionales.
- `prototype/`: flujo y referencia visual del prototipo; no convierte datos demo en reglas de producción.
- `adr/`: decisiones técnicas aceptadas y sus consecuencias.
- `architecture/`: límites entre superficies y responsabilidades de integración.
- `plans/`: planes de ejecución; el plan activo debe señalar archivos, interfaces y verificaciones.

Cuando dos documentos entren en conflicto, se corrige la spec o se registra un ADR de cambio antes de implementar. Las decisiones aprobadas de fundación están en `docs/superpowers/specs/2026-10-02-yegamo-platform-foundations-design.md`.

## Superficies canónicas

```text
context/specs/           comportamiento y contratos del producto
context/prototype/       flujo y look del prototipo
context/adr/             decisiones técnicas
context/architecture/    topología y límites de integración
api/contracts/openapi.yaml contrato HTTP ejecutable/documentable
api/db/migrations/       fuente de verdad del esquema SQL versionado
yegamo_app/              cliente Flutter
api/                     monolito modular NestJS y worker
```

`api/contracts/openapi.yaml` es la fuente del contrato HTTP; cualquier cliente o controlador debe alinearse con él. `api/db/migrations/` es la fuente del esquema SQL aplicado a entornos; el SQL de referencia publicado en las specs debe indicar la versión equivalente.

## Baseline aprobada

- [Diseño de fundaciones](../docs/superpowers/specs/2026-10-02-yegamo-platform-foundations-design.md)
- [Plan de workspace y contrato](../docs/superpowers/plans/2026-10-02-yegamo-workspace-contract-foundations-plan.md)
- [Contrato OpenAPI canónico](../api/contracts/openapi.yaml)
- [Matriz de trazabilidad](architecture/traceability.md)
- [Cierre de fundaciones](plans/FOUNDATIONS-CLOSEOUT.md)

El cierre de fundaciones confirma que la documentación, las decisiones, el
contrato HTTP y la referencia del prototipo están listos para los planes de
implementación. No implica que el API NestJS, las migraciones SQL o las
pantallas Flutter ya estén implementados.

## Invariantes de producto

- No se inventa una ETA y `LIVE` requiere una fuente autorizada y timestamp reciente.
- El backend decide confiabilidad, frescura, calidad y estado de datos; Flutter presenta esos estados.
- Los DTOs de proveedores no atraviesan el gateway hacia el dominio o el cliente.
- La ubicación precisa no se persiste por defecto y el API no almacena contraseñas.
- Los datos demo del prototipo, incluidos `RutaYa`, `Metrovia GTFS`, horarios y scores, son únicamente referencias o fixtures marcados.
