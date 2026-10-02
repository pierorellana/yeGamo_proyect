# Especificacion de aplicacion movil Flutter - yeGamo

## Plataforma
Flutter para Android/iOS desde una base de codigo comun. El prototipo actual usa viewport de referencia 393 x 852 y una experiencia visual inspirada en iOS, pero la implementacion debe ser responsive y respetar safe areas en ambas plataformas.

## Pantallas baseline (17)
1. Splash
2. Onboarding
3. Permisos
4. Inicio
5. Buscar lugares
6. Cercano
7. Planificador
8. Cargando
9. Alternativas
10. Hora de salida
11. Paso a paso
12. Viaje activo
13. Alerta de bajada
14. Guardados
15. Rutinas
16. Avisos
17. Ajustes

## Arquitectura canonica
Arquitectura modular inspirada en la estructura existente del proyecto: `env`
para configuracion y tema, `modules` para capacidades de producto y `shared`
para capacidades reutilizables.

```text
lib/
  env/
    config/
    theme/
  modules/
    onboarding/
    permissions/
    home/
    search/
    nearby/
    planner/
    journey/
    saved/
    commutes/
    notifications/
    settings/
  shared/
    models/
    services/
    security/
    session/
    localization/
    notifications/
    storage/
    location/
    routes/
    navigation/
    widgets/
    design_system/
    analytics/
```

- Cada modulo organiza sus archivos por `pages`, `widgets`, `models`,
  `providers` y `services`; no se impone una carpeta global
  `presentation/domain/data`.
- Estado: `provider` + `ChangeNotifier` + `MultiProvider`.
- Navegacion: `MaterialApp` + rutas nombradas + `Navigator` + `IndexedStack`.
- HTTP: un servicio compartido unico con autenticacion, `traceId`, timeout,
  retry controlado y mapeo de errores canonicos.
- Modelos de dominio desacoplados de DTOs de proveedores.

Los providers coordinan carga, vacio, error y mapeo de respuestas. Los
servicios no reciben `BuildContext` ni contienen reglas de negocio. Las
capacidades reutilizables se consolidan en `shared` antes de duplicarse en un
modulo.

## Estados UX obligatorios
`ok`, `loading`, `empty`, `error`, `offline`, `stale`, `degraded`, `permission`, `nocoverage`.

Deben representarse mediante componentes reutilizables: banner contextual, empty state, error state y acciones de recuperacion.

## Ubicacion
- `while-in-use` por defecto.
- Nunca solicitar `always` en el primer inicio.
- Si se deniega, usar origen manual.
- Viaje activo puede usar frecuencia adaptativa.
- Background solo cuando una funcion explicitamente lo justifique.

## Guardados / invitado
- Persistencia local para Casa, Trabajo y favoritos.
- Si el usuario inicia sesion, ofrecer sincronizacion/migracion.
- No bloquear planificacion ni guardados basicos por no tener cuenta.

## Notificaciones
- Push remoto: FCM/APNs.
- Alerta de bajada: preferir notificacion/local scheduling cuando sea tecnicamente viable.
- Deduplicacion por `notificationId`/`idempotencyKey`.

## Sistema visual
La implementacion debe conservar la jerarquia del prototipo: fondos oscuros, superficies discretas, cifras principales de alto contraste, chips redondeados y tipografia de sistema/SF Pro fallback Inter. Ver `25_DESIGN_SYSTEM.md`.

## Mapa
Abstraer proveedor. Diferenciar usuario, parada, ruta, vehiculo `LIVE` y `ESTIMATED`. Nunca usar el mismo indicador visual para live e inferido.

## Accesibilidad
- Dynamic text hasta limites razonables sin romper layouts.
- Contraste WCAG AA para texto funcional.
- Targets tactiles >= 44x44 pt aprox.
- Semantics para botones, tabs, progreso y score.
- No depender exclusivamente de color para estado.

## Analitica
`onboarding_completed`, `location_permission_result`, `journey_search`, `journey_plan_success`, `option_selected`, `leave_alert_created`, `leave_alert_opened`, `journey_started`, `getoff_alert_shown`, `journey_completed`, `commute_created`, `provider_fallback`, `degraded_state_shown`.

## Seguridad movil
Tokens en secure storage; no secrets privilegiados embebidos; logging sin coordenadas exactas por defecto; certificate/network hardening razonable.
