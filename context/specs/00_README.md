# yeGamo - Paquete de especificaciones

**Version:** 1.1.1
**Fecha de corte funcional:** 2 de octubre de 2026
**Investigacion externa base:** 19 de septiembre de 2026
**Estado:** Baseline normalizado y alineado al prototipo navegable

Este paquete actualiza la baseline original de RutaYa al producto **yeGamo** y la sincroniza con el prototipo movil ya construido. El principio central se mantiene: **yeGamo debe reducir la incertidumbre del transporte publico y ayudar al usuario a llegar a tiempo.**

## Cambios principales v1.1

- Rebranding completo de **RutaYa** a **yeGamo**.
- Alineacion de alcance con las **17 pantallas** del prototipo: Splash, Onboarding, Permisos, Inicio, Buscar, Cercano, Planificar, Cargando, Alternativas, Cuando salir, Paso a paso, Viaje activo, Alerta de bajada, Guardados, Rutinas, Avisos y Ajustes.
- Formalizacion de los estados UX: `ok`, `loading`, `empty`, `error`, `offline`, `stale`, `degraded`, `permission`, `nocoverage`.
- Rutinas, centro de avisos y configuracion de preferencias pasan a formar parte del **MVP de producto** porque ya estan representados en el prototipo.
- Se agregan contratos de alertas/notificaciones y preferencias a la API.
- Se documenta el sistema visual actual y el uso del nuevo nombre/logo.
- Se incorpora una matriz de trazabilidad prototipo -> requerimientos.
- Se corrige una inconsistencia importante: las referencias del prototipo a "Metrovia GTFS" son **datos de demostracion**. No deben presentarse como fuente real en produccion mientras no exista una integracion verificada/autorizada.

## Normalizacion 1.1.1

- La arquitectura movil canonica es `lib/env`, `lib/modules` y `lib/shared`, con `provider`, `ChangeNotifier`, `MultiProvider`, `MaterialApp`, rutas nombradas, `Navigator` e `IndexedStack`.
- El API canonico se publica como OpenAPI 3.1 bajo `/v1` e incluye identidad, migracion de invitado, dispositivos, preferencias, privacidad y los flujos funcionales del MVP.
- `14_SCHEMA.sql` es una referencia derivada del esquema versionado; la fuente ejecutable del esquema sera `api/db/migrations`.
- El modelo canonico incorpora legs/eventos de viaje, preferencias, instalaciones de dispositivo, entregas de notificacion, solicitudes de exportacion y salud de proveedores.

## Stack base acordado

- Aplicacion movil: Flutter (Android/iOS).
- Backend: Node.js + TypeScript; NestJS como framework de referencia.
- Base de datos: PostgreSQL + PostGIS.
- Integraciones de movilidad: Provider Gateway + adapters.
- API propia: REST/JSON versionada bajo `/v1`.
- Notificaciones: FCM/APNs y notificaciones locales.
- Arquitectura movil: modular `env/modules/shared`, con `provider` + `ChangeNotifier`.

## Fuente de verdad

1. Este paquete v1.1 define **comportamiento y contratos**.
2. El prototipo `yeGamo Prototype.html` define la **referencia visual y de flujo**.
3. La investigacion de fuentes externas permanece fechada al 19-09-2026 y debe revalidarse antes de una decision de produccion.

## Orden recomendado de lectura

1. `01_PRODUCT_REQUIREMENTS.md`
2. `24_PROTOTYPE_TRACEABILITY.md`
3. `25_DESIGN_SYSTEM.md`
4. `02_BUSINESS_RULES.md`
5. `03_FUNCTIONAL_REQUIREMENTS.md`
6. `04_NON_FUNCTIONAL_REQUIREMENTS.md`
7. `05_USE_CASES.md`
8. `06_USER_STORIES.md`
9. `08_MVP_SCOPE_ROADMAP.md`
10. `11_API_SPEC.md` y `12_OPENAPI.yaml`
11. `13_DATABASE_SPEC.md` y `14_SCHEMA.sql`
12. `15_MOBILE_FLUTTER_SPEC.md`
13. `16_BACKEND_NODE_SPEC.md`
14. `17_SECURITY_PRIVACY.md`, `18_ANALYTICS_METRICS.md`, `19_TESTING_ACCEPTANCE.md`, `20_RISKS_ASSUMPTIONS.md` y `21_ADR.md`.

## Precedencia y consistencia

Cuando haya una discrepancia, se aplica esta precedencia: comportamiento y
contratos de este paquete; decisiones aprobadas en el diseño de fundaciones;
flujo y look del prototipo; datos historicos del paquete o del prototipo.
Toda inconsistencia que afecte implementacion debe quedar registrada en
`CHANGELOG.md` o en una decision arquitectonica posterior. Los nombres,
horarios, scores y fuentes mostrados por el prototipo son demo y no fijan
valores productivos.
