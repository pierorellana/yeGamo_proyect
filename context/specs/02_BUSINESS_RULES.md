# Reglas de negocio

## BR-001 - Naturaleza de las estimaciones
Toda hora de llegada o salida calculada debe presentarse como estimacion. Cuando la incertidumbre supere el umbral configurado, se mostrara un rango (ej. 07:52-08:00) en lugar de una hora unica.

## BR-002 - Composicion del tiempo total
`tiempo_total = caminata_origen + espera + transporte + transbordos + caminata_destino + margen_seguridad`.

## BR-003 - Hora recomendada de salida
`hora_salida = hora_objetivo_llegada - percentil_estimado_del_viaje - margen_usuario`. El percentil utilizado aumenta cuando la confiabilidad de la ruta es baja.

## BR-004 - Ranking de alternativas
Cada opcion se puntua con pesos configurables. Baseline MVP: tiempo total 45%, confiabilidad 25%, caminata 15%, transbordos 10%, preferencia personal 5%. Los pesos se ajustan si el usuario selecciona "caminar menos", "menos transbordos" o "mayor confiabilidad".

## BR-005 - Confiabilidad
El indice de fiabilidad de yeGamo se expresa de 0 a 100 y nunca se interpreta como probabilidad exacta. Debe considerar calidad de fuente, recencia, cantidad de observaciones, dispersion historica y consistencia entre ETA esperado y observado.

## BR-006 - Fuentes de datos
Cada dato de movilidad debe conservar metadatos de origen (`provider`, `provider_ref`, `observed_at`, `license_policy`, `freshness`). La app mostrara una advertencia o degradara funciones cuando la fuente este desactualizada.

## BR-007 - Posicion de bus
Solo se etiquetara una unidad como "En vivo" cuando provenga de una fuente autorizada de vehicle positions/GPS con marca temporal. Una posicion inferida se mostrara como "Estimado" y visualmente distinta.

## BR-008 - Planificacion sin cuenta
Un usuario anonimo puede consultar cercania, buscar y planificar. Una cuenta es necesaria para sincronizar favoritos, perfiles recurrentes, historial en la nube y reputacion comunitaria.

## BR-009 - Privacidad de ubicacion
La ubicacion precisa se procesa durante la accion que la requiere. El historial persistente de ubicaciones se mantiene desactivado por defecto; solo se guarda con consentimiento explicito y proposito definido.

## BR-010 - Recalculo
Un viaje activo se recalcula cuando cambie materialmente la ETA, se detecte una incidencia relevante o una alternativa supere a la actual por el umbral configurado.

## BR-011 - Notificaciones
No se enviara una alerta de salida si el nivel de confianza es insuficiente y no existe margen razonable. En ese caso se enviara una recomendacion conservadora o se informara la limitacion.

## BR-012 - Reportes comunitarios
Los reportes deben expirar. Valores iniciales: ocupacion 15 min; retraso 30 min; unidad detenida 30 min; accidente/trafico 60 min; desvio/cierre 120 min, renovables por confirmaciones.

## BR-013 - Reputacion
La relevancia de un reporte depende de proximidad, recencia, numero de confirmaciones, reputacion del autor y concordancia con otras fuentes. No se publica un "ranking social" del usuario; la reputacion se utiliza para ponderar informacion.

## BR-014 - Ocupacion
La ocupacion comunitaria usa categorias cualitativas: baja, media, alta, saturada. Nunca se presentara como conteo exacto salvo que provenga de una fuente oficial que lo entregue.

## BR-015 - Rutas recurrentes
Un perfil recurrente contiene origen, destino, dias, hora objetivo y preferencia. yeGamo puede sugerir crear el perfil despues de observar un patron, pero nunca lo activa sin confirmacion.

## BR-016 - Margen de seguridad
El margen se adapta a confiabilidad y preferencia del usuario. Baseline: 5 min alto, 8 min medio, 12 min bajo. El usuario puede configurar un margen adicional.

## BR-017 - Datos licenciados
Datos de terceros con restricciones de almacenamiento o redistribucion se consumen en tiempo de consulta y no se incorporan permanentemente al repositorio canonico salvo permiso contractual.

## BR-018 - Degradacion elegante
Si falla la fuente principal, el sistema intentara una fuente secundaria compatible. Si no existe, mostrara rutas basicas o informacion estatica disponible; nunca inventara una posicion o ETA.

## BR-019 - Explicabilidad
Cuando la salida recomendada cambie mas de 5 minutos, el sistema debe poder explicar una causa disponible: nueva ETA, retraso, incidencia, cambio de ruta, fuente actualizada o aumento de margen.

## BR-020 - Alcance geografico
El MVP se valida primero en Guayaquil. La arquitectura y el modelo de dominio no deben codificar nombres de cooperativas, ciudades o proveedores de forma rigida para permitir expansion.

## BR-021 - Fuente visible en UI
La UI solo puede mostrar el nombre de una fuente de transporte como real/actualizada cuando el backend haya identificado un proveedor configurado y autorizado. Textos del prototipo como "Metrovia GTFS" se consideran **mock/demo** hasta que exista una fuente verificada.

## BR-022 - Estados de calidad de datos
Toda planificacion puede devolver `CURRENT`, `STALE`, `DEGRADED`, `OFFLINE_CACHE` o `UNAVAILABLE`. La presentacion debe corresponder con los estados visuales del prototipo.

## BR-023 - Modo invitado
Guardados y preferencias pueden existir localmente en modo invitado. La sincronizacion multi-dispositivo requiere cuenta. La UI debe explicar esta diferencia antes de solicitar registro.

## BR-024 - Avisos accionables
El centro de avisos solo contiene eventos de negocio utiles: salida, cambio material de ETA, alerta de bajada, cambio de rutina o afectacion de ruta. No se usara como feed generico.

## BR-025 - Rutinas sugeridas
yeGamo puede sugerir una rutina al detectar un patron, pero la rutina no se crea ni activa sin confirmacion del usuario.
