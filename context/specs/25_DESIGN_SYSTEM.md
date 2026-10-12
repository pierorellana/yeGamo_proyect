# Sistema visual baseline - yeGamo

## Marca
- Nombre visible: **yeGamo**.
- Símbolo «G-recorrido»: la G es un recorrido que arranca en un anillo de origen, da la vuelta y termina en un punto de destino (trazo 10/100, terminaciones redondeadas). Recursos en `yegamo_app/assets/logo/simbolo/`.
- Logotipo: palabra «yeGamo» con la G mayúscula (SF Pro Display Semibold, tracking −4 %); versión vectorial en `assets/logo/logotipo/` y lockup horizontal en `assets/logo/lockup/`.
- Splash solo tipográfico: las letras suben de a una, se dibuja una línea de trayecto de origen a destino y aparece «Sal a tiempo.» (3,5 s, se salta con un toque).
- Mantener zona de seguridad visual; no deformar, recolorear arbitrariamente ni mezclar con el nombre anterior.

## Paleta «Bosque claro» (prototipo `yeGamo-prototipo.html`)
| Token | Hex | Uso |
|---|---|---|
| Moss | `#2C3424` | Botón principal, texto fuerte, ruta elegida |
| Cypress | `#4C583E` | Acción «ir», en vivo, acentos |
| Olive | `#768064` | Caminata, apoyo del fondo |
| Cedar | `#959581` | Estimado, rutas alternativas |
| Aloe | `#DADED8` | Rellenos suaves |
| Clay | `#9C4F3A` | Solo errores y sin cobertura |
| Texto / 2 / 3 | `#1E2419` / `#5B624F` / `#6E7362` | Jerarquía de texto |
| Superficie / relleno / borde | `#FFFFFF` / `#EEF0EA` / `#E6E8E1` | Tarjetas y controles |

Fondo: blanco dominante con velo oliva de 13–17 % (gradiente `--yg-bg`). Los colores del mapa (tierra, manzanas, agua, parques) están en `yg_tokens.dart`.

## Tipografia
Fuente de plataforma: SF Pro Display/Text en Apple; **Geist** como respaldo en el resto (incluida en `assets/fonts/`). Cifras tabulares en horas.

Escala de referencia:
- Hora principal: 64 / 600 (−2,56). Resumen: 48 / 600.
- Título grande: 28 / 700. Título 2: 20 / 600. Título: 17 / 600.
- Subtítulo: 15 / 600. Cuerpo: 15 / 400. Secundario: 13 / 400. Meta: 12 / 400.
- Overline: 11 / 600 + tracking 0,06 em, mayúsculas.

## Componentes
- Botones píldora: 56 (entrada), 48 (estándar), 36 (en línea); iconos 44 / 36.
- Tarjetas radio 20, relleno 16, borde `#E6E8E1` y sombra suave; filas de lista de 56 con separador a 64.
- Panel inferior arrastrable con tres alturas (mínimo, intermedio, expandido) y resorte de 0,55 s; la cámara del mapa se ajusta al espacio visible y deja libre la columna de controles.
- Barra de pestañas flotante de vidrio con indicador que se desliza; avisos temporales y banners bajo la barra superior (y = 108).
- Banner de estado, chips de preferencia, barra de composición del tiempo, medidor de fiabilidad, lista de pasos/paradas.
- Mapa persistente con cámara 3D inclinada en viaje activo; vehículos «en vivo» (sólidos) y «estimados» (punteados).
- Empty/error states con acción recuperable e ilustración propia.

## Movimiento
Curvas base: spring de panel `cubic-bezier(.3,1.16,.4,1)` 0,55 s; salida suave `(.22,1,.36,1)` 0,5–0,7 s; toque `(.34,1.56,.64,1)` escala 0,96; cámara `(.2,.85,.25,1)` 1,3 s. Con «Reducir movimiento» se apagan cámara 3D, vuelos y pulsos y todo pasa a fundidos de 120 ms.

## Principios
1. Una cifra principal por pantalla cuando exista una decision temporal.
2. Reducir ruido visual.
3. Rangos visibles antes que precision falsa.
4. Estados live/estimated diferenciados por texto + forma, no solo color.
5. El tema claro «Bosque claro» es la baseline (ADR-009); el modo oscuro queda como variante futura.
6. Animaciones funcionales y breves; respetar `reduce motion`.
