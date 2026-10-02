# C-003: detalle de guest, OIDC y JWT para identidad

- **Estado:** accepted
- **Fecha:** 2026-10-02
- **Tipo:** complementaria
- **ADR canónico relacionado:** [ADR-006](ADR-006-oidc-jwt-authentication.md)
- **Ámbito:** identidad, autorización y migración de datos locales

## Contexto

El producto debe permitir planificar y guardar información localmente sin
obligar a crear una cuenta. Las funciones de sincronización, rutinas, historial,
avisos y privacidad requieren una identidad durable. yeGamo no debe almacenar
contraseñas ni acoplar el dominio a un proveedor de identidad específico.

La conversión de un invitado a una cuenta puede repetirse por reintentos de red,
por lo que debe ser explícita, idempotente y auditable.

## Decisión

El **modo guest** vive localmente en Flutter: permite planificación, favoritos,
Casa/Trabajo, recientes y planes permitidos por licencia. La app separa
secretos, preferencias estructuradas y cache; los tokens se guardan en
almacenamiento seguro.

La cuenta opcional usa un **proveedor OIDC configurable por ambiente**. El API
valida el JWT, verifica issuer, audience, firma, expiración y claims necesarios,
y vincula el `subject` externo con `users`. El backend nunca almacena
contraseñas ni elige un proveedor OIDC dentro del dominio.

Las rutas públicas pueden permitir búsqueda, cercanía y planificación anónima.
Sincronización, rutinas, historial, avisos, dispositivos y privacidad requieren
JWT válido. La migración guest→cuenta se invoca explícitamente, requiere
`Idempotency-Key`, valida propiedad del paquete local y registra el resultado.
Una repetición devuelve el mismo resultado sin duplicar favoritos, rutinas o
planes.

## Alternativas consideradas

1. **Autenticación propia con contraseñas:** descartada; añade custodia de
   credenciales y riesgos de recuperación que no son necesarios.
2. **Obligar cuenta desde el primer uso:** descartado; contradice la experiencia
   guest aprobada y aumenta la fricción de onboarding.
3. **Firebase/Auth0 fijo dentro del dominio:** descartado; impide cambiar de
   proveedor por ambiente y acopla reglas de negocio a infraestructura.
4. **Migración automática al detectar login:** descartada; puede sorprender al
   usuario y no es segura frente a reintentos ambiguos.

## Consecuencias

Positivas:

- El uso básico funciona sin identidad remota.
- El API conserva una frontera estándar basada en JWT/OIDC.
- La migración explícita permite confirmación, auditoría y reintentos seguros.
- Cambiar el proveedor OIDC no obliga a cambiar el dominio.

Costos y obligaciones:

- Deben gestionarse expiración, revocación o reautenticación según el proveedor.
- La app debe manejar la diferencia entre datos guest locales y datos de cuenta.
- Los endpoints protegidos necesitan pruebas de claims, scopes, ownership e
  idempotencia.

## Límites del MVP

- No se almacena contraseña ni se construye un servidor de identidad propio.
- No se fija un proveedor OIDC concreto dentro del código de dominio.
- La migración soporta el conjunto de datos local definido por producto; no es
  una sincronización general de dispositivos o historiales arbitrarios.

## Cómo se verifica

- Tests rechazan JWT con issuer, audience, firma o expiración inválidos.
- Tests de autorización distinguen rutas públicas de rutas de cuenta y validan
  ownership.
- Repetir la misma migración con el mismo `Idempotency-Key` no crea duplicados
  y conserva el resultado original.
- Logs y auditoría no incluyen tokens ni datos sensibles innecesarios.
