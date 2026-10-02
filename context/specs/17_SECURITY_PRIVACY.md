# Seguridad y privacidad

## Datos sensibles por contexto
La ubicacion precisa y patrones de desplazamiento pueden revelar rutinas. Se tratan como datos de alto impacto aunque no siempre sean categorias especiales.

## Controles
- Consentimiento granular para historial y viajes recurrentes.
- Modo invitado sin perfil permanente.
- Retencion corta para muestras de ubicacion.
- Cifrado en transito; cifrado de infraestructura en reposo.
- Secrets manager para credenciales de proveedores.
- Rate limiting y proteccion contra abuso de endpoints costosos.
- Borrado de cuenta y datos asociados.
- Exportacion de datos de usuario.
- Logs con coordenadas truncadas o eliminadas cuando no sean necesarias.

## Reportes comunitarios
- No exponer ubicacion exacta del reportante como identidad.
- Anti-spam, cooldown, limites por usuario/dispositivo.
- Moderacion de texto y adjuntos si se habilitan.

## Proveedores
Revisar terminos y politicas de almacenamiento antes de persistir respuestas. Mantener inventario de DPA/terminos/licencias por proveedor.
