# Design tokens baseline de yeGamo

Estos tokens documentan la referencia visual del prototipo
`yeGamo-prototipo.html` (paquete `yeGamo-prototipo-completo.zip`). Son una base compartida para Flutter; no convierten
los estilos inline del HTML en un contrato de negocio.

## Marca y color

La marca visible es `yeGamo`. Símbolo G-recorrido en headers y navegación;
lockup horizontal cuando haya espacio. No mostrar ni reintroducir `RutaYa`.
Los tokens ejecutables viven en `yegamo_app/lib/shared/design_system/yg_tokens.dart`
(generado a partir de `assets/colores-y-tokens/` del paquete del prototipo).

| Token | Valor | Uso |
|---|---|---|
| `moss` | `#2C3424` | Botón principal, texto fuerte, ruta elegida. |
| `cypress` | `#4C583E` | Acción «ir», en vivo, acentos. |
| `olive` | `#768064` | Caminata, apoyo del fondo. |
| `cedar` | `#959581` | Estimado, rutas alternativas. |
| `aloe` | `#DADED8` | Rellenos suaves. |
| `clay` | `#9C4F3A` | Solo errores y sin cobertura. |
| `text` / `text2` / `text3` | `#1E2419` / `#5B624F` / `#6E7362` | Jerarquía de texto. |
| `surface` / `fill` / `border` | `#FFFFFF` / `#EEF0EA` / `#E6E8E1` | Tarjetas, controles, bordes. |

Fondo «Bosque claro»: blanco dominante con velo oliva de 13–17 % (`YgBackground`).
Tema claro como baseline; el oscuro queda como variante futura (ADR-009).

## Tipografía

SF Pro Display/Text en Apple; Geist como respaldo en el resto de plataformas.

| Token | Tamaño / peso | Tracking | Uso |
|---|---:|---:|---|
| `heroTime` | `64 / 600` | `-2.56` | Hora de salida. |
| `summaryTime` | `48 / 600` | `-1.92` | Hora en tarjetas y panel. |
| `largeTitle` | `28 / 700` | `-0.7` | Título de pantalla. |
| `title2` | `20 / 600` | `-0.44` | Subtítulos de sección. |
| `title` | `17 / 600` | `-0.34` | Títulos de fila/panel. |
| `body` | `15 / 400` | `-0.15` | Copy funcional. |
| `secondary` | `13 / 400` | `-0.13` | Contexto y explicación. |
| `overline` | `11 / 600` | `0.66` | Etiquetas en mayúsculas. |

## Ritmo, radios y ergonomía

| Token | Valor | Uso |
|---|---:|---|
| `space` | `4 / 8 / 12 / 16 / 24 / 32` | Escala; margen lateral 16, entre secciones 24. |
| `radius.card` | `20` | Tarjetas (relleno 16, borde `#E6E8E1`). |
| `radius.tile` | `10` | Tiles de icono de 36. |
| `radius.sheet` | `32` | Panel inferior y hojas modales. |
| `radius.pill` | `9999` | Botones 56/48/36, chips 32, inputs. |
| `touch` | `44` mínimo | Target táctil accesible. |

## Componentes y estados

- Botón primario `moss` sobre claro; secundario `fill`; ghost `cypress`.
- Tarjeta blanca con borde y sombra suave; filas de 56 con separador a 64.
- Banner de estado contextual, recuperable y no modal (`warn`/`off`), bajo la
  barra superior (y = 108) cuando flota.
- Ruta: barra de composición (caminata punteada, espera rayada, bus, metro,
  transbordo, margen) y lista vertical de pasos con carril de 28.
- Navegación: barra de pestañas flotante de vidrio con indicador `moss`.

### LIVE y ESTIMATED

La diferencia entre estados nunca depende solo del color:

- `LIVE`: texto explícito `EN VIVO` y marca/forma sólida, solo si el backend
  entregó fuente autorizada y timestamp reciente.
- `ESTIMATED`: texto explícito `ESTIMADO` y contorno o indicador punteado;
  una posición inferida nunca se llama `LIVE`.
- `STALE`, `DEGRADED`, `OFFLINE_CACHE` y `UNAVAILABLE`: copy de estado,
  frescura visible y acción de recuperación según corresponda.

Respetar `reduce motion`; las animaciones funcionales deben ser breves. Los
targets táctiles deben ser aproximadamente `44x44pt` o mayores y el contraste
de texto funcional debe cumplir WCAG AA.
