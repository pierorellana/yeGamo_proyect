# yeGamo — mapa del workspace

El workspace raíz contiene `context/`, `yegamo_app/` y `api/`. Nunca se abre una superficie aislada sin leer este archivo y el README de `context/`.

Precedencia: comportamiento y contratos en `context/specs/`; flujo y look en `context/prototype/`; decisiones técnicas en `context/adr/`; ejecución en `docs/superpowers/plans/`.

SDD: spec → diseño/ADR → plan → implementación → pruebas → revisión → cierre.

Invariantes: no inventar ETA; no mostrar LIVE sin fuente y timestamp; no exponer DTOs de proveedores; no persistir ubicación precisa sin consentimiento; no almacenar contraseñas; no usar datos demo como producción.

Antes de tocar Flutter, leer `yegamo_app/AGENTS.md` si existe. Antes de tocar API o migraciones, leer `api/AGENTS.md` si existe.

## Reglas de trabajo

- Mantener los límites entre app, API, proveedores y persistencia documentados en `context/architecture/`.
- Toda modificación funcional debe actualizar primero la spec o explicar su desviación en un ADR.
- El contrato HTTP canónico es `api/contracts/openapi.yaml` y usa REST/JSON versionado bajo `/v1`.
- El esquema SQL canónico de ejecución vive en `api/db/migrations/`; `context/specs/14_SCHEMA.sql` es referencia derivada.
- Los cambios se validan con pruebas automatizadas y `git diff --check` antes del cierre.
- No versionar secretos, credenciales, artefactos generados ni datos de usuarios.

## Alcance de la primera entrega

El MVP se valida inicialmente en Guayaquil y conserva 17 pantallas y 9 estados UX como baseline. El sistema es un monolito modular escalable; no se introducen microservicios ni WebSocket/SSE sin una decisión nueva.
