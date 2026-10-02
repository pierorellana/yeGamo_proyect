# C-006: detalle de política de archivos sensibles y no versionados

- **Estado:** accepted
- **Fecha:** 2026-10-02
- **Tipo:** complementaria
- **ADR canónico relacionado:** [ADR-007](ADR-007-sensitive-files-policy.md)
- **Ámbito:** repositorio, desarrollo local, CI/CD y artefactos operativos

## Contexto

El API y la app necesitan configuración por ambiente, credenciales OIDC,
claves de proveedores, tokens de push, certificados y posibles exports de
datos. El repositorio es compartido y público o potencialmente visible para
colaboradores; un secreto en Git puede permanecer en el historial aunque se
borre después. Los dumps, logs y exports también pueden contener información
personal o coordenadas precisas.

## Decisión

Los secretos y datos sensibles se proporcionan por el entorno de ejecución o
por un gestor de secretos, nunca por archivos versionados. No se versionan:

- `.env`, `.env.*` reales, tokens, contraseñas, claves privadas, certificados
  privados ni service-account files;
- dumps de PostgreSQL, exports de usuarios, backups, logs con datos personales
  o coordenadas precisas y capturas de producción;
- caches, artefactos de build, coberturas, `node_modules`, `.dart_tool` y
  archivos generados que no sean una fuente canónica;
- credenciales de proveedores OIDC, mapas, push o transporte.

Sí se pueden versionar plantillas sin secretos, como `.env.example`, fixtures
anonimizados, ejemplos de contrato y seeds de desarrollo que no contengan
credenciales ni datos personales. Las muestras deben usar valores claramente
ficticios y coordenadas no sensibles.

La configuración se valida al iniciar: nombres y referencias pueden aparecer
en logs, pero nunca valores secretos, tokens, headers de autorización ni
coordenadas precisas innecesarias. Si un secreto se expone, se revoca y rota de
inmediato; eliminar el archivo del árbol no se considera remediación suficiente
del historial.

## Alternativas consideradas

1. **Versionar `.env` para simplificar onboarding:** descartado; filtra secretos
   y dificulta la rotación.
2. **Cifrar secretos dentro del repositorio:** descartado como baseline; las
   claves de descifrado seguirían necesitando distribución y el historial
   conservaría artefactos sensibles.
3. **Permitir dumps y logs locales sin reglas:** descartado; facilita filtrar
   datos personales y coordenadas.
4. **Confiar solo en `.gitignore`:** descartado; no detecta todo ni remedia un
   secreto ya confirmado en Git.

## Consecuencias

Positivas:

- El repositorio queda reproducible sin custodiar credenciales.
- La separación entre configuración, código y datos facilita rotación y CI.
- Fixtures y ejemplos pueden revisarse con menor riesgo de privacidad.

Costos y obligaciones:

- El entorno de desarrollo necesita instrucciones y valores de ejemplo seguros.
- CI/CD debe inyectar secretos y escanear commits, artefactos y logs.
- La eliminación o exportación de datos requiere controles de acceso y
  retención, no solo un archivo local.

## Límites del MVP

- La política cubre repositorio, desarrollo y CI/CD; no prescribe todavía un
  proveedor concreto de secret manager.
- Los datos demo del prototipo no son credenciales ni fixtures productivos.
- La ubicación precisa no se conserva por defecto, y las observaciones que la
  necesiten deben tener consentimiento y retención corta.

## Cómo se verifica

- Un escaneo de secretos bloquea tokens, claves privadas, service accounts y
  valores de `.env` antes del merge.
- CI comprueba que los archivos sensibles y artefactos locales estén excluidos,
  y que `.env.example` no contenga valores reales.
- Revisiones de logs verifican ausencia de tokens, headers de autorización y
  coordenadas precisas innecesarias.
- Una exposición se registra como incidente: revocación, rotación, limpieza
  del historial afectado y análisis de alcance.
