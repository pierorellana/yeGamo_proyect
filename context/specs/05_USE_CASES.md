# Casos de uso - yeGamo

## CU-00 Primer inicio
**Actor:** Invitado.
Splash -> onboarding de 3 mensajes -> permiso de ubicacion -> permitir while-in-use o continuar con origen manual -> Inicio.

## CU-01 Consultar transporte cercano
Ubicacion/punto -> consultar paradas/rutas -> normalizar proveedores -> ordenar por distancia/relevancia -> mostrar.
Alternos: permiso denegado -> origen manual; proveedor sin realtime -> etiquetar estimado/programado.

## CU-02 Buscar destino
Inicio -> Buscar -> origen prellenado/manual -> texto de destino -> recientes/resultados -> seleccionar -> Planificador.

## CU-03 Planificar "Salir ahora"
Origen/destino -> preferencia -> margen -> proveedor(es) -> alternativas -> normalizacion -> fiabilidad/ranking -> 1-3 opciones -> seleccion.

## CU-04 Planificar "Llegar a las"
Usuario define hora objetivo -> sistema obtiene alternativas -> aplica margen/fiabilidad -> calcula hora recomendada -> muestra ventana de llegada -> permite crear alerta.

## CU-05 Resolver estado sin opciones
Si ninguna alternativa cumple hora/criterios -> mostrar estado `empty` -> permitir mover hora, ampliar caminata o editar parametros.

## CU-06 Resolver error de proveedor
Timeout/falla -> fallback -> si no existe respuesta util, mostrar error explicito y `traceId` -> reintentar. Nunca inventar ETA.

## CU-07 Consultar hora de salida
Seleccion -> hora recomendada -> desglose de tiempo y margen -> explicacion de ajustes -> crear aviso -> ver pasos o iniciar viaje.

## CU-08 Viaje activo
Iniciar -> progreso -> ETA -> proximas paradas -> recalculos -> alerta de bajada -> finalizar.

## CU-09 Alerta de bajada
Cuando el usuario se aproxima al descenso -> alerta prominente -> indicar siguiente parada y caminata posterior -> `Entendido` o `Posponer` si aplica.

## CU-10 Guardar lugares
Invitado/usuario -> Guardados -> agregar Casa/Trabajo/personalizado -> almacenar localmente o sincronizar si hay cuenta.

## CU-11 Gestionar rutina
Crear/editar/pausar rutina -> origen/destino/dias/hora -> evaluar en dias aplicables -> generar recomendacion/aviso.

## CU-12 Sugerir rutina por patron
Detectar patron local/servidor segun consentimiento -> mostrar sugerencia -> usuario descarta o confirma.

## CU-13 Centro de avisos
Mostrar avisos accionables -> abrir contexto -> marcar leido -> marcar todos leidos.

## CU-14 Ajustes y privacidad
Gestionar ubicacion, historial, preferencia, caminata maxima, margen, avisos, exportacion y eliminacion.

## CU-15 Estado degradado
Offline/stale/degraded/permission/no coverage -> mostrar banner o estado especifico -> indicar limitacion -> permitir accion de recuperacion.

## CU-16 Consultar indice de fiabilidad
Abrir detalle -> verificar muestra minima -> mostrar score/nivel/contexto -> si no hay evidencia suficiente, mostrar `datos insuficientes`.

## CU-17 Reportar incidencia (post-MVP)
Usuario activo -> tipo -> ubicacion/ruta -> validacion -> publicar con expiracion -> confirmaciones/resolucion.
