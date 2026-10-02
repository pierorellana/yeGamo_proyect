# Requerimientos no funcionales

- **RNF-001 Rendimiento:** p95 de busqueda/planificacion propia < 2.5 s excluyendo latencia extraordinaria de proveedores; responder con estado de procesamiento o fallback si se supera el timeout.
- **RNF-002 Disponibilidad:** objetivo MVP 99.5% mensual para API propia; las dependencias externas se monitorean separadamente.
- **RNF-003 Escalabilidad:** componentes stateless siempre que sea posible; datos geoespaciales indexados con PostGIS.
- **RNF-004 Seguridad:** TLS, secretos fuera del codigo, validacion de entrada, rate limiting, logs sin ubicacion precisa innecesaria.
- **RNF-005 Privacidad:** minimizacion, consentimiento, retencion definida, eliminacion/exportacion de datos personales.
- **RNF-006 Observabilidad:** trazas por request, proveedor usado, latencia, errores, cache/fallback, sin exponer tokens.
- **RNF-007 Accesibilidad:** soporte de lector de pantalla, contraste, escalado de texto, targets tactiles y mensajes no dependientes solo de color.
- **RNF-008 Internacionalizacion:** interfaz preparada para es/en; unidades y zona horaria configurables.
- **RNF-009 Offline parcial:** favoritos, ultimas rutas consultadas y datos basicos permitidos por licencia pueden estar disponibles sin conexion; nunca mostrar ETA antigua como actual.
- **RNF-010 Compatibilidad:** Android/iOS con matriz de versiones definida en release; permisos de ubicacion justificados por funcionalidad.
- **RNF-011 Mantenibilidad:** modulos por dominio, contratos de proveedor, tests de negocio y migraciones versionadas.
- **RNF-012 Portabilidad de proveedor:** una integracion externa no puede filtrar estructuras propietarias hacia la UI; toda respuesta pasa por DTO canonico.
- **RNF-013 Exactitud:** registrar error ETA observado vs estimado para calibracion; no prometer precision no medida.
- **RNF-014 Cost control:** cuota y costo por proveedor medidos por endpoint y usuario para prevenir abuso.
