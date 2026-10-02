# ADR-006: autenticación guest, OIDC y JWT

- **Estado:** accepted
- **Fecha:** 2026-10-02
- **Ámbito:** identidad, autorización y migración guest→cuenta

## Contexto

El usuario debe poder planificar y guardar localmente sin registrarse, mientras
que sincronización, rutinas, historial, avisos, dispositivos y privacidad
requieren una identidad durable. yeGamo no debe almacenar contraseñas ni
acoplar el dominio a un proveedor de identidad concreto.

## Decisión

El modo guest vive localmente en Flutter. La cuenta opcional usa OIDC
configurable por ambiente. El API valida el JWT, incluyendo issuer, audience,
firma, expiración y claims necesarios, y vincula el `subject` externo con
`users`. El backend no almacena contraseñas.

Las rutas públicas pueden permitir búsqueda, cercanía y planificación anónima.
Las operaciones de cuenta requieren JWT válido. La migración guest→cuenta es
explícita, requiere `Idempotency-Key`, valida propiedad y registra el resultado
para que los reintentos no dupliquen datos.

## Alternativas consideradas

1. **Contraseñas propias:** descartadas por custodia y recuperación de
   credenciales.
2. **Cuenta obligatoria desde onboarding:** descartada por la experiencia guest.
3. **Proveedor OIDC fijo dentro del dominio:** descartado por acoplamiento.
4. **Migración automática al iniciar sesión:** descartada por sorpresa y
   ambigüedad en reintentos.

## Consecuencias

- El uso básico no depende de identidad remota.
- El API tiene una frontera estándar y portable basada en JWT/OIDC.
- La app debe separar secretos, preferencias, cache guest y datos sincronizados.
- Se requieren pruebas de claims, ownership, expiración e idempotencia.

## Límites del MVP

- No se construye un servidor de identidad propio.
- No se elige un proveedor OIDC concreto en el dominio.
- La migración cubre los datos guest permitidos por producto, no una réplica
  arbitraria de historiales entre dispositivos.

## Cómo se verifica

- Tests rechazan JWT inválidos por issuer, audience, firma o expiración.
- Tests de autorización distinguen rutas públicas, cuenta y ownership.
- Repetir una migración con la misma clave devuelve el resultado original sin
  duplicados.
- Logs y auditoría no contienen tokens ni datos sensibles innecesarios.
