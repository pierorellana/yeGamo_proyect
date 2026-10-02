# yeGamo — cierre de fundaciones

**Fecha:** 2026-10-02
**Estado:** aprobado para implementación por subproyectos
**Alcance:** workspace SDD, specs v1.1.1, ADRs, contrato REST/OpenAPI y trazabilidad del prototipo.

## Commits del subproyecto

| Task | Commit | Resultado |
|---|---|---|
| 1 — Gobernanza SDD | `b680765` | Workspace, precedencia, límites y reglas operativas |
| 2 — Specs normalizadas | `78a7027` | Paquete canónico v1.1.1, manifest y OpenAPI normalizado |
| 3 — ADRs | `2a28c88` | Decisiones aceptadas de workspace, Flutter, API, datos, auth y proveedores |
| 4 — Contrato HTTP | `45e5f66` | `api/contracts/openapi.yaml`, ejemplos y guía de contrato |
| 5 — Trazabilidad | `0f3fb09` | 17 pantallas, 9 estados, tokens y matriz RF/integración/pruebas |

## Gates ejecutados

### Sintaxis

```text
ruby YAML.load_file(context/specs/12_OPENAPI.yaml)       → YAML OK
ruby YAML.load_file(api/contracts/openapi.yaml)          → YAML OK
ruby JSON.parse(context/specs/manifest.json)             → JSON OK
ruby JSON.parse(api/contracts/examples/*.json)            → JSON OK
```

La copia normalizada y el contrato canónico exponen 35 paths y 41 operaciones
coincidentes. La versión OpenAPI es `3.1.0` y el contrato es `1.1.1`.

### Consistencia de decisiones

```text
rg Riverpod|go_router|Dio context/specs                         → sin referencias normativas
rg RutaYa|Metrovia GTFS|16 pantallas|8 estados context/specs → solo historial/deuda/demo explícita
git diff --check                                                → limpio
```

Las reglas verificadas incluyen `LIVE` con fuente autorizada y timestamp,
`OFFLINE_CACHE`/`STALE`, `Idempotency-Key`, `traceId`, guest migration explícita
e idempotente, y ausencia de contraseñas persistidas.

### Trazabilidad

```text
Pantallas baseline       → 17, incluyendo Cargando
Estados UX               → 9: ok, loading, empty, error, offline, stale, degraded, permission, nocoverage
Grupos RF                → 7 grupos documentados en architecture/traceability.md
Tokens de color         → 7 valores aprobados
```

## Documentos canónicos para implementación

- Comportamiento y contratos: `context/specs/`.
- Decisiones técnicas: `context/adr/`.
- Límites de integración: `context/architecture/`.
- Flujo visual: `context/prototype/`.
- Contrato HTTP: `api/contracts/openapi.yaml`.
- Ejemplos de contrato: `api/contracts/examples/`.
- Esquema SQL ejecutable futuro: `api/db/migrations/`.
- Cliente Flutter existente: `yegamo_app/`.

## Trabajo restante

Este cierre no declara implementados los runtimes. Los siguientes planes SDD
requeridos son:

1. `api-and-database`: scaffold NestJS, módulos, gateway, repositorios,
   migraciones SQL/PostGIS, seeds demo aislados, auth, jobs y pruebas de
   contrato/integración.
2. `flutter-app`: adaptación de `yegamo_app/` a `env/modules/shared`,
   providers/services, navegación, estados UX, cliente HTTP y pruebas de
   widgets/integración.

Cada plan debe leer este cierre y los ADRs antes de modificar código. Las
migraciones son la fuente ejecutable de datos; `context/specs/14_SCHEMA.sql`
permanece como referencia derivada versionada.
