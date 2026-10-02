# Estrategia de pruebas y aceptacion - yeGamo

## Unitarias
- calculo hora de salida.
- ranking de alternativas.
- margen automatico + extra.
- nivel de fiabilidad y muestra minima.
- expiracion de reportes.
- mapeo provider -> modelo canonico.
- deduplicacion de avisos.
- deteccion de cambios materiales > umbral.

## Widget/UI tests Flutter
- onboarding 3 pasos.
- permiso aceptado / denegado.
- home con banner offline/stale/degraded/permission.
- planificador en ambos modos temporales.
- alternativas ok/empty/error/nocoverage.
- hora de salida y desglose de margen.
- alerta de bajada.
- guardados invitado.
- rutina activa/pausada/sugerida.
- centro de avisos y marcar leidos.

## Contract tests
Fixtures por proveedor para cambios de schema, ausencia de campos y stale data.

## Integracion
PostgreSQL/PostGIS real en CI; mock controlado de proveedores; FCM/APNs abstraidos.

## Migraciones y persistencia
- Ejecutar todas las migraciones desde una base vacia y comprobar el esquema
  esperado, extensiones, indices y constraints.
- Ejecutar la ruta de upgrade desde la version anterior soportada y comprobar
  que no se pierden datos ni se rompen claves externas.
- Verificar que `14_SCHEMA.sql` permanece alineado como referencia derivada de
  `api/db/migrations`.
- Probar migracion invitado->cuenta con reintentos, misma `Idempotency-Key` y
  resultados duplicados: la operacion debe ser idempotente y auditable.
- Registrar y revocar instalaciones de dispositivo sin duplicar tokens ni
  entregas.

## E2E movil
1. Primer inicio -> onboarding -> permiso -> home.
2. Buscar -> planificar -> alternativa -> hora de salida -> pasos -> viaje -> alerta -> finalizar.
3. Permiso denegado -> origen manual.
4. Provider down -> fallback/degraded.
5. Provider timeout sin fallback -> error, sin ETA inventada.
6. Guardar lugar como invitado -> persistir al reiniciar.
7. Crear rutina -> pausar -> reanudar.
8. Crear aviso -> recibir una sola notificacion.
9. Offline con plan cacheado -> banner y datos marcados.
10. No coverage -> mensaje y accion de retorno.
11. `OFFLINE_CACHE` presenta cache con frescura visible y `STALE` no se etiqueta
    como actual.
12. Ninguna respuesta marca `LIVE` sin fuente autorizada y timestamp reciente.

## Criterios de salida MVP
- 100% de las 17 pantallas implementadas o explicitamente feature-flagged segun alcance.
- >=95% de planes validos devuelven respuesta util en zona piloto cuando la fuente tiene cobertura.
- Ningun vehiculo aparece `LIVE` sin timestamp/fuente autorizada.
- Estados `OFFLINE_CACHE` y `STALE` se conservan en contrato, mapeo y UI.
- Ningun nombre de fuente mock del prototipo aparece en produccion sin configuracion real.
- Alertas no se duplican.
- Eliminacion de cuenta probada.
- Observabilidad permite identificar proveedor y motivo de fallback.
- Accesibilidad basica y responsive validados en tamanos iPhone/Android representativos.
