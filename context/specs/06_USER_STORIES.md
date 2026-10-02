# Historias de usuario y criterios de aceptacion - yeGamo

## Epic A - Primer uso y privacidad
**US-A01** Como usuario quiero entender el valor de yeGamo antes de entregar permisos.
**AC:** el onboarding explica hora de salida, rango honesto y viaje activo; puede omitirse.

**US-A02** Como usuario quiero usar la app sin compartir ubicacion.
**AC:** puedo elegir origen manual y la app explica que funciones se limitan.

## Epic B - Descubrimiento y busqueda
**US-B01** Como pasajero quiero ver paradas cerca.
**AC:** se listan con distancia; si no hay datos, se informa sin inventar resultados.

**US-B02** Como usuario quiero buscar un destino usando recientes y resultados.
**AC:** el origen puede ser ubicacion/manual; seleccionar resultado abre planificacion.

## Epic C - Planificacion
**US-C01** Como usuario quiero indicar origen/destino y hora objetivo.
**AC:** se devuelven alternativas con tiempo total, caminata, transbordos, ventana y fiabilidad.

**US-C02** Como usuario quiero priorizar confiabilidad, caminar menos o hacer menos transbordos.
**AC:** el ranking cambia y la seleccion queda visible antes de recalcular.

**US-C03** Como usuario quiero saber por que debo salir a cierta hora.
**AC:** la pantalla de salida muestra desglose de tiempo, margen automatico, margen personal y causa de ajustes.

## Epic D - Viaje activo
**US-D01** Como viajero quiero ver si sigo llegando a tiempo.
**AC:** se muestra ETA, ventana objetivo y progreso.

**US-D02** Como visitante quiero que me avisen antes de bajar.
**AC:** se dispara una alerta antes del descenso y se indica la siguiente accion.

## Epic E - Guardados y rutinas
**US-E01** Como invitado quiero guardar Casa y Trabajo sin crear cuenta.
**AC:** se persiste localmente y se explica que no se sincroniza.

**US-E02** Como trabajador quiero una rutina recurrente.
**AC:** define dias/hora y puede pausarse o editarse.

**US-E03** Como usuario quiero aceptar o rechazar una rutina sugerida.
**AC:** nunca se crea automaticamente.

## Epic F - Avisos
**US-F01** Como usuario quiero un centro de avisos util.
**AC:** solo contiene eventos accionables; permite marcar leidos y evita duplicados.

## Epic G - Confianza y degradacion
**US-G01** Como usuario quiero saber que tan estable es una alternativa.
**AC:** el indice se muestra solo con muestra suficiente y nunca como garantia.

**US-G02** Como usuario quiero saber cuando los datos son viejos o parciales.
**AC:** se muestra estado stale/degraded/offline y la app no presenta datos inventados como actuales.
