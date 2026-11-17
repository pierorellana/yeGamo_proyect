# Cierre de la finalización del MVP (2026-11-17)

Estado real tras ejecutar `docs/superpowers/plans/2026-11-17-yegamo-mvp-completion-roadmap.md`
contra la solicitud de las diez fases. Decisiones: [ADR-010](../adr/ADR-010-guayaquil-transit-data-source.md),
[ADR-011](../adr/ADR-011-mvp-completion-identity-and-guest-journeys.md).

## Verificado (ejecutado en esta sesión)

| Área | Comando | Resultado |
|---|---|---|
| API unitarias/contrato | `npm test` | 16 suites · 63 pruebas OK |
| API contra PostgreSQL 18 + PostGIS 3.6 | `DATABASE_URL=… npm run test:e2e` | 8 suites · 25 pruebas OK (migraciones 0001–0011, persistencia de plan tras «reinicio», plan→start→progress→finish por HTTP real con JWT RS256 firmado localmente, migración guest, preferencias, alertas, scheduler) |
| Flutter | `flutter analyze` / `flutter test` | sin issues · 179 pruebas OK |
| Android release | `flutter build apk --release` | ver «Estado de producción» |

## No verificado

- `integration_test/*` (necesitan dispositivo/simulador; el arranque falló sin dispositivo). Se actualizaron al contrato nuevo pero **no se ejecutaron**.
- Dispositivo físico (Android/iOS), permisos reales en segundo plano, build iOS release.
- Login OIDC real (no hay proveedor ni credenciales).
- Entrega push (sin FCM/APNs).

## Por fase

1. **Contrato Flutter↔API** — hecho. `POST /v1/journeys/{planId}/options/{optionId}/start`; progreso solo `currentLegIndex`/`location`/`occurredAt`; `ActiveJourney` con `planId`, `legs`, `dataQuality`; respuestas que rompen el contrato se rechazan; finish/cancel devuelven 200 como documenta OpenAPI.
2. **DTOs** — hecho. Favoritos y rutinas solo se sincronizan con coordenadas válidas y ids del servidor (lo demás queda local y rotulado); rutinas con la forma `CommuteProfile`; notificaciones leen `isRead`; export de cuenta con `POST /me/data-export`. Bug real corregido: el API aceptaba `LESS_WALKING`/`FEWER_TRANSFERS` pero PostgreSQL los rechazaba (migración 0010).
3. **Persistencia** — hecho. Migración 0009; `PrismaJourneyPlanRepository`; el repositorio en memoria ya no existe en runtime.
4. **Flujo vertical** — hecho con fixture explícito (dos tramos a pie, `DEGRADED`, sin fuente autorizada). El invitado sigue el viaje localmente; con sesión se registra en el API.
5. **Identidad** — parcial. Hecho: ciclo de tokens, expiración/refresco, caída a invitado, migración guest→cuenta real (antes era un stub que no importaba nada), sincronización de consentimiento. **Falta** pantalla de login y registro de dispositivos (decisión de proveedor OIDC).
6. **Proveedor real** — investigación documentada; **no existe** fuente gratuita con horarios/ETA para Guayaquil. Única fuente real: OSM (paradas y trazados). `/journeys/plan` sin demo responde 503.
7. **Alertas** — parcial. Hecho: `POST /alerts/leave` desde «Hora de salida» (solo con hora de salida real), deduplicación, disparo único, expiración, scheduler en proceso. **Falta** entrega push/local y permisos de notificación (requiere FCM/APNs y un plugin nativo no verificable aquí).
8. **Viaje activo** — parcial. Hecho: instrucciones por tramo, progreso, recuperación tras reinicio, avance por evidencia de ubicación (fin de tramo), aviso de desvío en tramos a pie, alternativa manual. **Falta**: ETA (sin fuente), geocerca de bajada en segundo plano, seguimiento en background.
9. **Mapa** — parcial. Hecho: selección por toque, marcadores de origen/destino, tramos a pie punteados, encuadre de cámara. Los tramos en transporte **no se dibujan** (el plan no trae geometría). No hay vehículos en vivo. El renderizado nativo MapLibre no se pudo verificar visualmente.
10. **Producción** — parcial. Hecho: rate limiting (429 canónico), cabeceras de seguridad, caché offline de planes (TTL 24 h, solo sin red), scheduler con bloqueos, variables documentadas, Android release (INTERNET, firma por `key.properties`). **Falta**: analytics del funnel (no hay colector definido), métricas/observabilidad, applicationId definitivo (`com.example.*`), iOS release, pruebas en dispositivo, E2E de Flutter contra API real.

## Pendientes reales (bloqueados)

1. Elegir e integrar un proveedor OIDC (login, registro de dispositivo).
2. Fuente con horarios: solicitar GTFS/licencia a la ATM.
3. Credenciales FCM/APNs para push.
4. Colector de analytics.
5. Identificador de aplicación definitivo y firma de release.
