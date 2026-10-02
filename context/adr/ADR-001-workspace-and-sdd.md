# ADR-001: workspace y SDD

- **Estado:** accepted
- **Fecha:** 2026-10-02
- **Ámbito:** repositorio raíz, documentación y ciclo de entrega

## Contexto

yeGamo tiene una app Flutter existente, un API por construir y especificaciones
que deben permanecer alineadas. Abrir repositorios o superficies aisladas
facilitaría contradicciones entre comportamiento, prototipo, contrato y código.

## Decisión

Se usará un único repositorio raíz con `context/`, `yegamo_app/` y `api/`.
`context/specs/` es la fuente de comportamiento y contratos funcionales;
`context/prototype/` es la referencia visual y de flujo; `context/adr/` fija
decisiones técnicas; `docs/superpowers/plans/` define la ejecución.

El ciclo SDD obligatorio es:

```text
spec → diseño/ADR → plan → implementación → pruebas → revisión → cierre
```

Cuando haya conflicto, la precedencia operativa es `specs → prototype → ADR →
plan`, interpretada sin violar las decisiones explícitas aprobadas en ADRs.

## Alternativas consideradas

1. **Repositorios independientes para app y API:** descartado; dificulta la
   trazabilidad y la evolución coordinada del contrato.
2. **Código como única fuente de comportamiento:** descartado; perdería las
   decisiones y criterios de aceptación antes de implementar.
3. **Documentación libre sin precedencia:** descartado; permite contradicciones
   entre prototipo, specs y arquitectura.

## Consecuencias

- Las fronteras app/API/DB se revisan en el mismo cambio documentado.
- Cada implementación debe enlazar requisitos, decisión, plan y pruebas.
- El workspace exige disciplina para no duplicar fuentes normativas.
- Los cambios grandes requieren actualizar el contexto antes del código.

## Límites del MVP

- El workspace no obliga todavía a desplegar API y Flutter juntos.
- El prototipo no es fuente de horarios, scores, fuentes ni disponibilidad real.
- No se reabre una decisión aceptada sin un ADR de cambio.

## Cómo se verifica

- Las nuevas tareas identifican spec, ADR, plan, archivos y pruebas.
- Las revisiones comprueban que no haya una segunda fuente normativa sin enlace.
- El README del contexto y este índice mantienen enlaces a los documentos
  canónicos.
