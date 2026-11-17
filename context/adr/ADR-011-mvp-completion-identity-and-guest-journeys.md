# ADR-011: viajes de invitado, planes persistidos e identidad pendiente de proveedor

- **Estado:** accepted
- **Fecha:** 2026-11-17
- **Relacionados:** [ADR-006](ADR-006-oidc-jwt-authentication.md), [ADR-010](ADR-010-guayaquil-transit-data-source.md)

## Decisiones

1. **Planes persistidos.** `journey_plans/options/legs` (migraciones 0004 y 0009)
   guardan planes canónicos —nunca DTOs de proveedor— y expiran a las 24 h.
   `POST /journeys/plan` sigue siendo público (`user_id` NULL). Los ids de
   proveedor se sustituyen por UUID propios.
2. **Contrato de viaje activo.** `ActiveJourney` devuelve `planId`, `legs` con
   instrucciones y `dataQuality`; `currentLegIndex` es el único campo de progreso
   (siempre `< legs.length`; la llegada se registra con `finish`). `dataState`
   hereda el de la opción: nunca se promueve a `CURRENT`.
3. **Viajes de invitado locales.** El API exige JWT para viajes activos
   (ADR-006). Un invitado sigue los tramos reales de la opción elegida
   **localmente**, sin llamar al API ni inventar datos; con sesión el viaje se
   registra en el API.
4. **Identidad.** El API valida JWT OIDC. **No hay proveedor OIDC elegido ni
   credenciales**, así que no se construyó la pantalla de login (requiere una
   decisión del producto y un cliente OIDC registrado). Ya existe el ciclo de
   tokens (almacén seguro, expiración, `refresh_token` único en vuelo, caída a
   invitado sin perder datos), la migración guest→cuenta real y la sincronización
   de preferencias. Configuración por `YEGAMO_OIDC_TOKEN_ENDPOINT` y
   `YEGAMO_OIDC_CLIENT_ID` (públicos, sin secretos).
5. **Alertas.** Las alertas de salida solo se programan con una hora de salida
   real del plan; un scheduler en proceso (`WORKERS_ENABLED=true`) las dispara
   una sola vez. La entrega push/local queda deshabilitada hasta tener
   credenciales de FCM/APNs (no se versionan secretos).
