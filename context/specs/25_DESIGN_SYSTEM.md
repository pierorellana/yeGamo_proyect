# Sistema visual baseline - yeGamo

## Marca
- Nombre visible: **yeGamo**.
- Logotipo horizontal: recurso `yegamo-logo.png`.
- Isotipo/cuadrado: recurso `yegamo-mark-sq.png`.
- Usar el isotipo en espacios compactos (home/header/iconografia de marca) y el logotipo completo en splash/onboarding cuando exista espacio.
- Mantener zona de seguridad visual; no deformar, recolorear arbitrariamente ni mezclar con el nombre anterior.

## Paleta observada en el prototipo
- `#0C0C0C` - base oscura.
- `#121212` - superficies/fondo secundario.
- `#252525` - cards y elementos elevados.
- `#235E5D` - acento teal discreto.
- `#F5F5F5` - texto/accion principal.
- `#8C8C8E` - texto secundario.
- `#9A9A9D` - texto terciario/estado neutral.

Los tonos teal deben usarse como acento, no como fondo dominante general.

## Tipografia
Fuente preferida de plataforma: `SF Pro Display/Text` en iOS con fallback `Inter`, `system-ui`.

Escala de referencia:
- Display decision: 46 / 600.
- Metrica: 25 / 600.
- Titulo de pantalla: 21 / 600.
- Etiqueta: 15 / 600.
- Cuerpo: 15 / 400.
- Secundario: 13 / 400.
- Overline: 11 / 600 + tracking.

## Componentes
- Pill CTA principal.
- Card de superficie `#252525`.
- Banner de estado.
- Chips de preferencia.
- Barra de composicion del tiempo.
- Indicador de fiabilidad.
- Lista de pasos/paradas.
- Bottom navigation con tab activo de alto contraste.
- Empty/error states con accion recuperable.

## Principios
1. Una cifra principal por pantalla cuando exista una decision temporal.
2. Reducir ruido visual.
3. Rangos visibles antes que precision falsa.
4. Estados live/estimated diferenciados por texto + forma, no solo color.
5. Dark mode es baseline; modo claro queda como variante futura.
6. Animaciones funcionales y breves; respetar `reduce motion`.
