# Límites de integración

Las superficies se comunican mediante contratos explícitos. Una capa puede solicitar datos a la siguiente, pero no puede trasladarle responsabilidades que pertenezcan a su límite.

| Capa | Puede hacer | No puede hacer |
|---|---|---|
| Flutter widget | interacción, presentación, navegación | HTTP, reglas de negocio, autorización |
| Flutter provider/service | cargar, mapear, persistir localmente | decidir confiabilidad, inventar ETA |
| API application/domain | reglas, ranking, autorización, calidad | renderizar UI |
| Provider gateway | consultar y normalizar proveedores | publicar DTO propietario |
| Persistencia | guardar datos autorizados y constraints | decidir copy o estado visual |

## Contratos entre superficies

- Flutter ↔ API: REST/JSON versionado bajo `/v1`, documentado en `api/contracts/openapi.yaml`; la respuesta incluye estados de calidad/frescura cuando aplique.
- API ↔ proveedores: interfaces canónicas (`TransitPlannerProvider`, `GeocodingProvider`, `VehiclePositionProvider`, `TrafficIncidentProvider`) y adapters aislados; el proveedor nunca define el modelo público.
- API ↔ persistencia: repositorios y migraciones versionadas; los límites de transacción, locking y consultas geoespaciales son explícitos.
- API ↔ worker: casos de uso reutilizables y jobs idempotentes; la ejecución fuera de la petición no cambia el contrato visible.

## Reglas de datos honestos

`LIVE` solo se muestra si existe fuente autorizada y timestamp reciente. Una posición inferida se marca `ESTIMATED`; una falta de cobertura se expresa como `UNAVAILABLE` o `DEGRADED`. La app conserva un cache local identificado como `OFFLINE_CACHE`, pero no lo presenta como dato actual.

Los trace IDs, nombres de proveedor, latencias y fallbacks sirven para observabilidad; no se registran secretos ni coordenadas precisas sin consentimiento. La sincronización de invitado a cuenta es explícita, idempotente y auditable.
