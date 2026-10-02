# Contrato HTTP de yeGamo

`openapi.yaml` es la fuente canónica del contrato REST/JSON v1. El servidor se
publica bajo `/v1` y las rutas autenticadas usan un JWT emitido por un proveedor
OIDC configurado por ambiente (`bearerAuth`). Las rutas públicas declaran
explícitamente `security: []`.

`context/specs/12_OPENAPI.yaml` es la copia normalizada de referencia que debe
mantener las mismas operaciones, nombres de schemas y reglas de seguridad que
este archivo. El contrato canónico debe ser la primera superficie que se
actualice cuando cambie una operación.

## Reglas de implementación

- No se agregan controllers sin actualizar contrato, ejemplo y prueba de
  contrato en la misma corrida.
- Los errores usan `code`, `message`, `details` y `traceId`; el `traceId` también
  puede viajar como header de respuesta para correlación operativa.
- `Idempotency-Key` es obligatorio en operaciones que crean o cambian efectos
  que podrían duplicarse al reintentarse.
- La calidad de movilidad usa `dataState`; `LIVE` exige una fuente autorizada y
  un `observedAt` reciente. `providerDisplayName` es nullable.
- Los ejemplos son fixtures contractuales de Guayaquil y no declaran una fuente
  demo como productiva.

## Ejemplos

- [`journey-plan-request.json`](examples/journey-plan-request.json)
- [`journey-plan-response.json`](examples/journey-plan-response.json)
- [`error.json`](examples/error.json)

Validación local mínima:

```bash
python3 -c "import yaml; yaml.safe_load(open('api/contracts/openapi.yaml'))"
```
