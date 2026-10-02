# Trazabilidad del prototipo yeGamo

## Objetivo
Evitar que el prototipo y las especificaciones evolucionen por separado. Cada pantalla debe tener una responsabilidad funcional y requerimientos asociados.

La baseline canonica de esta version es exactamente **17 pantallas** y **9
estados UX**. El conteo no se infiere de textos descriptivos del HTML: se toma
del listado navegable y de los estados observables del prototipo.

| # | Pantalla | Responsabilidad | Requerimientos |
|---|---|---|---|
| 1 | Splash | Identidad y transicion inicial | RF-004 |
| 2 | Onboarding | Explicar propuesta de valor | RF-004 |
| 3 | Permisos | Ubicacion while-in-use u origen manual | RF-005, RF-010 |
| 4 | Inicio | Decidir rapido: cuando salir / buscar / accesos | RF-040, RF-011 |
| 5 | Buscar | Origen, destino, recientes, mapa | RF-011, RF-012, RF-014 |
| 6 | Cercano | Paradas/rutas y live vs estimated | RF-020..RF-024 |
| 7 | Planificador | Hora objetivo, preferencia, margen | RF-030..RF-037 |
| 8 | Cargando | Feedback durante consulta | RF-038 |
| 9 | Alternativas | Comparar opciones y estados de error | RF-032..RF-034, RF-085..RF-087 |
|10 | Hora de salida | Recomendacion, margen, explicacion, aviso | RF-040..RF-044 |
|11 | Paso a paso | Tramos e instrucciones | RF-035 |
|12 | Viaje activo | Progreso, ETA, paradas | RF-050..RF-056 |
|13 | Alerta de bajada | Aviso de siguiente descenso | RF-052 |
|14 | Guardados | Casa/Trabajo/personalizados | RF-013, RF-060, RF-065 |
|15 | Rutinas | Recurrencia y patron sugerido | RF-061..RF-064 |
|16 | Avisos | Centro de eventos accionables | RF-070..RF-074 |
|17 | Ajustes | Privacidad, preferencias, cuenta | RF-003, RF-088, RF-089 |

## Estados del prototipo

| Estado | Uso especificado |
|---|---|
| `ok` | Respuesta normal |
| `loading` | Consulta en curso |
| `empty` | Sin alternativas/resultados |
| `error` | Error de proveedor o dominio recuperable |
| `offline` | Sin red; posible cache |
| `stale` | Datos mas antiguos que el umbral |
| `degraded` | Respuesta parcial/fallback |
| `permission` | Ubicacion desactivada |
| `nocoverage` | Fuera de zona soportada |

## Inconsistencias detectadas y decision

### Nombre anterior
El prototipo embebido aun conserva algunas etiquetas internas/descriptivas `RutaYa`. Se consideran deuda de limpieza y no deben aparecer en la app final. La marca visible oficial es **yeGamo**.

### Conteo de pantallas
Una descripcion del artefacto menciona 16 pantallas; el `screenList` contiene **17**, incluyendo `Cargando`. La especificacion adopta 17.

### "Metrovia GTFS"
El prototipo muestra textos como `Metrovia GTFS - actualizado hace 4 min` y `Datos: Metrovia GTFS - OpenStreetMap`, pero la investigacion base no confirma un feed oficial publico de GTFS/GTFS-RT. Por tanto:
- se mantiene como **mock de demostracion**;
- en produccion el nombre visible debe venir del backend;
- si no existe fuente verificada, usar copy generico como `Datos de transporte actualizados hace X min`.

### Datos simulados
Horarios, lugares, score 84, muestra de 132 viajes y otras cifras del prototipo son demostrativas. Sirven para validar jerarquia y componentes, no para fijar defaults de negocio.
