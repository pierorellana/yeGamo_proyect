# ADR-008: MVP sin proveedor autorizado y fixtures del prototipo

- **Estado:** accepted
- **Fecha:** 2026-10-12
- **Tipo:** canónica
- **Ámbito:** transporte, geocodificación, contrato HTTP, App Flutter y pruebas

## Contexto

El MVP se valida inicialmente en Guayaquil, pero todavía no existe un
proveedor autorizado de transporte o geocodificación. El prototipo contiene
lugares, horarios, ETA, scores y nombres de fuente que sirven para validar el
flujo y la composición visual, pero no acreditan cobertura ni disponibilidad
productiva. Mostrar esos datos como actuales produciría una promesa falsa.

La plataforma necesita conservar la baseline de 17 pantallas y 9 estados UX,
permitir pruebas deterministas y dejar una frontera clara para incorporar una
fuente real en el futuro.

## Decisión

Durante el MVP providerless:

1. Producción no inyecta `DemoTransitProvider` ni un adapter inventado. Cuando
   una capacidad depende de una fuente ausente, el gateway devuelve el error
   HTTP `503` `PROVIDER_UNAVAILABLE` con `details.dataState: UNAVAILABLE`, la
   capacidad afectada, un indicador de reintento y `traceId`. La respuesta
   también conserva `X-Trace-Id`.
2. `LOCATION_OUT_OF_COVERAGE` queda reservado para una fuente autorizada que
   existe, pero no cubre la ubicación consultada. No se usa para ocultar la
   ausencia de proveedor.
3. Los campos de fuente permanecen `providerDisplayName: null` y
   `sourceAuthorized: false` cuando no hay una fuente autorizada. `LIVE` exige
   una fuente autorizada, `observedAt` reciente y una posición válida.
4. `DemoTransitProvider` y los fixtures del HTML/ZIP solo se habilitan con una
   configuración explícita de desarrollo, pruebas o demo marcada. Sus
   respuestas se etiquetan `DEGRADED`, nunca `LIVE`, y no se mezclan con los
   repositorios productivos.
5. La baseline conserva exactamente estas 17 pantallas: Splash, Onboarding,
   Permisos, Inicio, Buscar, Cercano, Planificador, Cargando, Alternativas,
   Hora de salida, Paso a paso, Viaje activo, Alerta de bajada, Guardados,
   Rutinas, Avisos y Ajustes. `arrived` y `nocov` son estados UX —terminal de
   llegada y sin cobertura—, no pantallas adicionales.

## Consecuencias

### App Flutter

- Mapea `PROVIDER_UNAVAILABLE`/`UNAVAILABLE` a un estado recuperable con
  acción explícita, sin convertir un `503` en una ETA local.
- Mapea `LOCATION_OUT_OF_COVERAGE` a `nocoverage` y ofrece origen manual,
  cambio de parámetros o regreso según la capacidad.
- Puede renderizar la composición del prototipo sin pintar calles, vehículos,
  rutas o ETA ficticias en producción.

### API y gateway

- El dominio depende de modelos canónicos y nunca recibe DTOs de proveedor.
- El contrato canónico es `api/contracts/openapi.yaml`; todo cambio de
  respuesta, header o metadata debe reflejarse también en la copia derivada y
  sus ejemplos.
- La observabilidad conserva `traceId` en el body y `X-Trace-Id` en las
  respuestas de error.

### Pruebas

- Los contract tests cubren ausencia de proveedor, timeout, fuera de cobertura,
  `X-Trace-Id`, metadata de calidad y bloqueo de `LIVE` falso.
- Los fixtures demo se pueden usar para validar las 17 pantallas y los 9
  estados, pero deben ser explícitos y no pueden ser defaults productivos.

## Incorporación futura de un proveedor

Antes de habilitar una fuente real deben existir autorización, cobertura
verificada para Guayaquil, licencia y política de almacenamiento, configuración
por ambiente, adapter aislado, mapper canónico, pruebas de contrato,
observabilidad y una decisión de activación. Solo después de superar esos
criterios una respuesta puede declarar `CURRENT` o `LIVE`; la incorporación no
requiere cambiar las rutas públicas ni exponer DTOs externos.

## Alternativas descartadas

- Usar los datos del prototipo como fallback productivo: confunde fixture con
  disponibilidad real.
- Inventar un proveedor o afirmar una cobertura mínima: no es verificable y
  rompe la regla de datos honestos.
- Ocultar la ausencia detrás de una respuesta vacía: impide distinguir
  `UNAVAILABLE` de `LOCATION_OUT_OF_COVERAGE` y dificulta la recuperación.
- Cambiar las rutas físicas `yegamo_app/` y `api/`: rompe tooling y no resuelve
  la frontera de integración.

## Verificación

- `rg -n "RutaYa|Metrovia GTFS|LIVE|UNAVAILABLE|arrived|nocov" context api/contracts`
- Tests de contrato para `503` en places y `X-Trace-Id`.
- Tests de gateway con provider deshabilitado, demo opt-in y provider
  autorizado fake.
- `git diff --check`.
