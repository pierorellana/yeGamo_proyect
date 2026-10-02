# yeGamo — decisiones arquitectónicas

Este directorio registra decisiones aceptadas que gobiernan la implementación
del workspace, la app Flutter, el API, la persistencia, la identidad, los
proveedores y el manejo de datos. Los cinco ADRs canónicos requeridos por la
Tarea 3 son la fuente principal. Las decisiones complementarias amplían esos
ADRs sin cambiar sus límites; una modificación requiere un ADR posterior que
explique el cambio, su impacto y su migración.

Fecha de baseline: `2026-10-02`
Estado de la colección: `accepted`

## ADRs canónicos de la Tarea 3

| ADR | Estado | Alcance | Specs relacionadas |
|---|---|---|---|
| [ADR-001 — Workspace y SDD](ADR-001-workspace-and-sdd.md) | accepted · 2026-10-02 | Repositorio raíz, precedencia documental y ciclo SDD | `00_README.md`, `21_ADR.md`, `23_SOURCE_REFERENCES.md` |
| [ADR-002 — API modular NestJS](ADR-002-modular-nestjs-api.md) | accepted · 2026-10-02 | Monolito modular, límites de dominio, jobs y crecimiento | `11_API_SPEC.md`, `16_BACKEND_NODE_SPEC.md` |
| [ADR-003 — Arquitectura Flutter modular](ADR-003-flutter-modular-architecture.md) | accepted · 2026-10-02 | `env/modules/shared`, Provider, navegación y cliente HTTP | `15_MOBILE_FLUTTER_SPEC.md`, `25_DESIGN_SYSTEM.md` |
| [ADR-004 — Migraciones y acceso SQL-first](ADR-004-sql-first-migrations-and-data-access.md) | accepted · 2026-10-02 | Migraciones, Prisma Client, `pg` y PostgreSQL/PostGIS | `13_DATABASE_SPEC.md`, `14_SCHEMA.sql` |
| [ADR-005 — Gateway y datos honestos](ADR-005-provider-gateway-and-honest-data.md) | accepted · 2026-10-02 | Adapters, fallback, frescura, calidad y `LIVE` | `02_BUSINESS_RULES.md`, `09_EXTERNAL_DATA_RESEARCH.md`, `10_INTEGRATION_STRATEGY.md` |

## ADRs adicionales aceptados

| ADR | Estado | Alcance | Specs relacionadas |
|---|---|---|---|
| [ADR-006 — Auth guest/OIDC/JWT](ADR-006-oidc-jwt-authentication.md) | accepted · 2026-10-02 | Invitado, cuenta opcional, JWT y guest migration | `11_API_SPEC.md`, `17_SECURITY_PRIVACY.md` |
| [ADR-007 — Archivos sensibles](ADR-007-sensitive-files-policy.md) | accepted · 2026-10-02 | Secretos, credenciales, exports, dumps y artefactos locales | `17_SECURITY_PRIVACY.md`, `20_RISKS_ASSUMPTIONS.md` |

## Decisiones complementarias

Estos archivos conservan el detalle creado previamente. No son IDs canónicos
adicionales: se identifican como `C-*` dentro del documento y amplían el ADR
canónico indicado.

| Complementaria | Relación |
|---|---|
| [C-001 — Detalle del backend modular](ADR-001-modular-monolith-backend.md) | Amplía [ADR-002](ADR-002-modular-nestjs-api.md) |
| [C-002 — Detalle de persistencia](ADR-002-sql-first-persistence.md) | Amplía [ADR-004](ADR-004-sql-first-migrations-and-data-access.md) |
| [C-003 — Detalle de identidad](ADR-003-guest-oidc-jwt-authentication.md) | Amplía [ADR-006](ADR-006-oidc-jwt-authentication.md) |
| [C-004 — Detalle del gateway](ADR-004-provider-gateway.md) | Amplía [ADR-005](ADR-005-provider-gateway-and-honest-data.md) |
| [C-005 — Detalle de frescura](ADR-005-data-freshness-and-honesty.md) | Amplía [ADR-005](ADR-005-provider-gateway-and-honest-data.md) |
| [C-006 — Detalle de archivos sensibles](ADR-006-sensitive-files-policy.md) | Amplía [ADR-007](ADR-007-sensitive-files-policy.md) |

## Cómo usar estos ADRs

- `context/specs/` define comportamiento y contratos funcionales.
- Este directorio fija decisiones técnicas que afectan varias superficies.
- `docs/superpowers/plans/` define la ejecución concreta de cada decisión.
- El contrato HTTP canónico será `api/contracts/openapi.yaml`; las
  implementaciones no deben crear rutas o estados fuera de ese contrato sin
  actualizar la documentación correspondiente.

Los límites del MVP siguen siendo obligatorios: no se crean microservicios, no
se requiere WebSocket/SSE, no se almacena una ubicación precisa por defecto,
no se guardan contraseñas y `DemoTransitProvider` no es una fuente productiva.
