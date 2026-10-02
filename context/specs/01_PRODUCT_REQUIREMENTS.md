# Product Requirements Document (PRD) - yeGamo

## 1. Vision

yeGamo es un asistente de movilidad urbana que ayuda a las personas a descubrir, planificar y anticipar desplazamientos en transporte publico. La experiencia principal se formula como: **"Dime a que hora necesitas llegar y yeGamo te dira cuando debes salir."**

El prototipo actual traduce esta vision en una experiencia mobile-first, oscura, directa y centrada en una decision principal: **la hora recomendada de salida**.

## 2. Problema

El usuario no solo desconoce que transporte tomar; tambien desconoce cuanto esperara, cuanto demorara realmente el viaje, si la alternativa es confiable y cuanto margen necesita para llegar a tiempo. La incertidumbre obliga a salir demasiado temprano o aumenta el riesgo de atraso.

## 3. Usuarios objetivo

- Trabajador con desplazamientos recurrentes casa-trabajo.
- Estudiante con horarios fijos.
- Usuario ocasional que desconoce la red de transporte.
- Visitante que necesita instrucciones claras para subir, transbordar y bajar.
- Usuario que prioriza confiabilidad, menor caminata o menos transbordos.

## 4. Jobs to be Done

- Cuando debo estar en un lugar a una hora especifica, quiero saber cuando salir para reducir el riesgo de llegar tarde.
- Cuando estoy en una zona que no conozco, quiero descubrir transporte cercano.
- Cuando ya estoy viajando, quiero saber si sigo llegando a tiempo y cuando debo bajar.
- Cuando repito un trayecto, quiero recibir la recomendacion sin planificarlo manualmente cada dia.
- Cuando los datos son incompletos o estan desactualizados, quiero saberlo claramente para no confundir una estimacion con un dato en vivo.

## 5. Objetivo general

Reducir la incertidumbre del transporte publico mediante planificacion, estimaciones contextuales, seguimiento, rutinas y alertas personalizadas.

## 6. Objetivos especificos

1. Descubrir paradas y opciones cercanas.
2. Planificar viajes origen-destino.
3. Calcular una ventana de llegada y una hora recomendada de salida.
4. Comparar alternativas por tiempo, caminata, transbordos y confiabilidad.
5. Acompañar al usuario durante un viaje activo.
6. Permitir guardar lugares y crear rutinas.
7. Gestionar avisos de salida, cambios relevantes y alerta de bajada.
8. Exponer de forma clara estados offline, stale, degraded, error y no coverage.
9. Construir historicos propios con consentimiento para calibrar estimaciones.

## 7. Propuesta de valor

yeGamo debe responder de forma simple a cuatro preguntas: **que puedo tomar, cuando deberia salir, cuando llegaria y que tan confiable es la recomendacion.**

## 8. North Star Metric

**Viajes completados dentro de la ventana de llegada prevista utilizando una recomendacion de yeGamo.**

## 9. Principios de producto y UX

- **Decision primero:** mostrar antes la accion que el usuario debe tomar y despues el detalle que la explica.
- **Rangos, no falsa precision:** usar ventanas de llegada cuando exista incertidumbre.
- **Explicabilidad:** si la hora recomendada cambia, explicar por que.
- **Degradacion honesta:** nunca inventar ETA, posiciones ni disponibilidad.
- **Minimo esfuerzo:** facilitar Casa, Trabajo, recientes, guardados y rutinas.
- **Privacidad por defecto:** ubicacion while-in-use e historial apagado por defecto.
- **Consistencia visual:** conservar jerarquia, espaciado, estados y lenguaje del prototipo.

## 10. Experiencia principal

`Splash -> Onboarding -> Permisos -> Inicio -> Buscar/Cercano -> Planificar -> Cargando -> Alternativas -> Cuando salir -> Paso a paso -> Viaje activo -> Alerta de bajada -> Llegada`

Flujos secundarios:

- `Inicio -> Guardados`
- `Guardados -> Rutinas`
- `Inicio -> Avisos`
- `Inicio -> Ajustes`

## 11. Alcance funcional de alto nivel

- Splash y onboarding de valor.
- Permiso de ubicacion o uso manual.
- Home con salida recomendada y accesos rapidos.
- Busqueda de lugares.
- Transporte cercano.
- Planificador con `Salir ahora` / `Llegar a las`.
- Preferencia de alternativa: confiable / menos caminata / menos transbordos.
- Margen extra configurable.
- Alternativas con ventana, caminata, espera, transbordos y confiabilidad.
- Hora recomendada y desglose del margen.
- Paso a paso.
- Viaje activo.
- Alerta de bajada.
- Guardados.
- Rutinas.
- Centro de avisos.
- Ajustes, privacidad y cuenta opcional.
- Estados degradados y de error.

## 12. No objetivos iniciales

- Cobro de pasaje o venta de boletos.
- GPS propio instalado en buses.
- Sustituir sistemas de control de flota.
- Navegacion vehicular privada.
- Transporte interprovincial.
- Comunidad/reporte de incidencias como requisito para lanzar el MVP.
- Mostrar una fuente "LIVE" si el proveedor no entrega posicion autorizada y timestamp reciente.

## 13. Identidad de producto

- Nombre oficial: **yeGamo**.
- Escritura de marca: `yeGamo` (respetar mayuscula interna).
- El nuevo simbolo y logotipo son la referencia visual del prototipo.
- El nombre anterior `RutaYa` queda deprecado y solo puede aparecer en historico de documentos/migraciones.
