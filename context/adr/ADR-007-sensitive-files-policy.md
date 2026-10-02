# ADR-007: política de archivos sensibles y no versionados

- **Estado:** accepted
- **Fecha:** 2026-10-02
- **Ámbito:** repositorio, desarrollo local, CI/CD y artefactos operativos

## Contexto

El proyecto usa configuración por ambiente, credenciales OIDC, claves de
proveedores, certificados, exports y logs. Un secreto confirmado en Git puede
permanecer en el historial aunque se borre del árbol. Exports, dumps y logs
pueden contener datos personales o coordenadas precisas.

## Decisión

Secretos y datos sensibles se inyectan por el entorno o un gestor de secretos,
nunca desde archivos versionados. No se versionan `.env` reales, tokens,
contraseñas, claves privadas, certificados privados, service accounts, dumps,
exports de usuarios, backups, logs sensibles, capturas de producción, caches ni
artefactos generados.

Se permiten `.env.example`, fixtures anonimizados, ejemplos de contrato y seeds
de desarrollo sin credenciales ni datos personales. La configuración valida al
iniciar y los logs excluyen secretos, headers de autorización y coordenadas
precisas innecesarias. Una exposición exige revocar, rotar y analizar el
historial afectado; borrar el archivo no basta.

## Alternativas consideradas

1. **Versionar `.env`:** descartado por filtración y rotación difícil.
2. **Cifrar secretos en Git:** descartado; las claves seguirían necesitando
   distribución y el historial conservaría artefactos.
3. **Confiar solo en `.gitignore`:** descartado; no detecta secretos ya
   confirmados ni cubre todos los artefactos.

## Consecuencias

- El repositorio es reproducible sin custodiar credenciales.
- CI/CD debe inyectar secretos y escanear commits, artefactos y logs.
- El onboarding necesita plantillas seguras y documentación de variables.
- Una exposición se trata como incidente, no como simple cambio de archivo.

## Límites del MVP

- La política no selecciona todavía un proveedor concreto de secret manager.
- Los datos demo son ejemplos, no fixtures productivos.
- La ubicación precisa no se persiste por defecto y las observaciones que la
  requieran tienen consentimiento y retención corta.

## Cómo se verifica

- Un escaneo de secretos bloquea tokens, claves privadas y valores reales de
  `.env` antes del merge.
- CI comprueba exclusión de artefactos y que `.env.example` no tenga secretos.
- Revisiones de logs verifican ausencia de tokens y coordenadas innecesarias.
