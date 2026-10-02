# Requerimientos funcionales - yeGamo

## Onboarding, cuenta y perfil
- **RF-001** Permitir modo invitado desde el primer uso.
- **RF-002** Registrar/iniciar sesion mediante proveedor de identidad soportado para sincronizacion.
- **RF-003** Configurar preferencia de viaje, caminata maxima y margen personal.
- **RF-004** Mostrar onboarding de valor antes de solicitar permisos.
- **RF-005** Permitir continuar sin ubicacion usando origen manual.

## Geolocalizacion y busqueda
- **RF-010** Obtener ubicacion actual con permiso while-in-use.
- **RF-011** Buscar lugares por texto.
- **RF-012** Seleccionar punto en mapa.
- **RF-013** Guardar Casa, Trabajo y lugares personalizados.
- **RF-014** Mostrar recientes y distancia/contexto cuando corresponda.

## Transporte cercano
- **RF-020** Consultar paradas cercanas en radio configurable.
- **RF-021** Listar rutas asociadas a una parada.
- **RF-022** Mostrar distancia/tiempo caminando hasta una parada.
- **RF-023** Mostrar proximas salidas/llegadas cuando la fuente lo soporte.
- **RF-024** Distinguir visualmente dato `LIVE` de dato `ESTIMATED`.

## Planificacion
- **RF-030** Planificar viaje con origen y destino.
- **RF-031** Permitir `Salir ahora` o `Llegar a las`.
- **RF-032** Generar una o mas alternativas.
- **RF-033** Mostrar caminata, espera, transporte, transbordos, duracion, rango de llegada y fiabilidad.
- **RF-034** Ordenar alternativas por preferencia.
- **RF-035** Mostrar instrucciones por tramos y puntos de subida/bajada.
- **RF-036** Permitir preferir: mayor fiabilidad, menos caminata o menos transbordos.
- **RF-037** Permitir configurar margen extra antes de calcular.
- **RF-038** Mostrar estado de calculo/carga y permitir cancelar.

## Hora de salida
- **RF-040** Calcular hora recomendada de salida.
- **RF-041** Mostrar la composicion del tiempo total y del margen.
- **RF-042** Permitir crear alerta previa a la salida.
- **RF-043** Recalcular antes de notificar cuando cambien condiciones.
- **RF-044** Explicar cambios materiales de la recomendacion.

## Viaje activo
- **RF-050** Iniciar viaje a partir de una alternativa.
- **RF-051** Mostrar progreso, paradas restantes y ETA.
- **RF-052** Alertar cuando se aproxime el punto de bajada.
- **RF-053** Detectar desviacion importante y sugerir recalculo.
- **RF-054** Finalizar/cancelar viaje.
- **RF-055** Mostrar si el usuario sigue dentro de la ventana prevista.
- **RF-056** Mostrar proximas paradas cuando la informacion lo permita.

## Guardados y rutinas
- **RF-060** Guardar lugares y viajes.
- **RF-061** Crear, pausar, editar y eliminar rutinas.
- **RF-062** Definir dias y hora objetivo de una rutina.
- **RF-063** Evaluar rutinas y generar recomendacion previa.
- **RF-064** Sugerir rutina al detectar un patron, requiriendo confirmacion.
- **RF-065** Mantener guardados locales en modo invitado.

## Avisos
- **RF-070** Mostrar centro de avisos.
- **RF-071** Registrar estado leido/no leido.
- **RF-072** Mostrar avisos de salida, cambio de ETA, alerta de bajada y cambios relevantes de ruta/rutina.
- **RF-073** Evitar duplicados por idempotencia.
- **RF-074** Permitir marcar avisos como leidos.

## Historico y confianza
- **RF-080** Guardar resultado de viaje con consentimiento.
- **RF-081** Calcular metricas agregadas por ruta/franja.
- **RF-082** Mostrar indice de fiabilidad 0-100 solo con evidencia suficiente.
- **RF-083** Explicar el nivel de fiabilidad en lenguaje simple.
- **RF-084** Mostrar fuente y frescura cuando sea relevante para diagnostico/transparencia.

## Estados y degradacion
- **RF-085** Soportar estados `loading`, `empty`, `error`, `offline`, `stale`, `degraded`, `permission` y `nocoverage`.
- **RF-086** Nunca mostrar ETA o posicion inventada cuando el proveedor no responda.
- **RF-087** Ofrecer acciones de recuperacion: reintentar, cambiar hora, permitir mas caminata, origen manual o volver.

## Ajustes y privacidad
- **RF-088** Gestionar acceso a ubicacion, historial, preferencias y avisos.
- **RF-089** Permitir exportar datos y solicitar eliminacion de cuenta/datos.

## Administracion
- **RF-090** Gestionar proveedores externos y su estado.
- **RF-091** Configurar umbrales de confianza, expiracion y ranking sin publicar nueva app.
- **RF-092** Consultar salud de integraciones y porcentaje de respuestas degradadas.

## Post-MVP / Community
- **RF-100** Crear reporte comunitario geolocalizado.
- **RF-101** Confirmar o marcar resuelta una incidencia.
- **RF-102** Registrar ocupacion cualitativa.
