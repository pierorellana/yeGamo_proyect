# ADR-003: arquitectura Flutter modular

- **Estado:** accepted
- **Fecha:** 2026-10-02
- **Ámbito:** aplicación móvil, estado, navegación y servicios compartidos

## Contexto

La app debe cubrir las pantallas y estados del prototipo sin crear imports
directos entre módulos. La arquitectura debe seguir la superficie modular de
`/Users/jorge/Desktop/context/app`, conservar estado entre secciones y separar
UI, coordinación, persistencia local y red.

## Decisión

La app usará:

```text
lib/env/
lib/modules/
lib/shared/
```

Cada módulo tendrá `pages`, `widgets`, `models`, `providers` y `services` según
necesidad. El estado usará `provider`, `ChangeNotifier` y `MultiProvider`.
La navegación usará `MaterialApp`, rutas nombradas, `Navigator` e
`IndexedStack` para conservar el estado de secciones principales.

Un cliente HTTP compartido vivirá en `shared/services` y resolverá auth,
traceId, timeout, reintentos controlados y mapeo de errores. Los servicios no
recibirán `BuildContext`; los providers manejarán carga, vacío, error, mapeo y
bloqueo de doble envío. Las capacidades reutilizables nuevas se consolidarán
en `shared`.

## Alternativas consideradas

1. **Imports directos entre módulos:** descartado porque crea acoplamiento y
   dificulta extraer o probar una feature.
2. **Riverpod, `go_router` o Dio como baseline:** descartados para respetar la
   arquitectura móvil aprobada y su patrón existente.
3. **Reglas de negocio en widgets:** descartado; las reglas pertenecen al API
   y a coordinadores/providers testeables.

## Consecuencias

- La estructura es familiar para el scaffold existente y escalable por feature.
- `shared` requiere revisión para evitar convertirse en un cajón sin límites.
- Se necesitan tests de providers, servicios, widgets y navegación.
- La app puede representar `CURRENT`, `STALE`, `DEGRADED`, `OFFLINE_CACHE` y
  `UNAVAILABLE` sin inventar calidad localmente.

## Límites del MVP

- Se mantienen las 17 pantallas y 9 estados baseline.
- No se introduce una navegación o gestor de estado alternativo.
- El almacenamiento local no convierte cache en ETA actual ni persiste ubicación
  precisa por defecto.

## Cómo se verifica

- La revisión de imports comprueba que módulos no dependan directamente entre
  sí y que lo reutilizable viva en `shared`.
- Tests verifican `ChangeNotifier`, estados de carga/error y bloqueo de doble
  envío.
- Widget e integration tests cubren las 17 pantallas y 9 estados.
