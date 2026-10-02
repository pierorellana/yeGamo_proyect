# Design tokens baseline de yeGamo

Estos tokens documentan la referencia visual observada en
`yeGamo Prototype.html`. Son una base compartida para Flutter; no convierten
los estilos inline del HTML en un contrato de negocio.

## Marca y color

La marca visible es `yeGamo`. Usar el logotipo horizontal
`yegamo-logo.png` cuando haya espacio y el isotipo
`yegamo-mark-sq.png` en headers, navegación y superficies compactas. No
mostrar ni reintroducir `RutaYa`.

| Token | Valor | Uso |
|---|---|---|
| `color.base` | `#0C0C0C` | Fondo oscuro principal y base del mapa. |
| `color.surface` | `#121212` | Fondo secundario y superficies de baja elevación. |
| `color.surfaceElevated` | `#252525` | Cards, paneles y elementos elevados discretos. |
| `color.accent` | `#235E5D` | Acento teal discreto; no debe dominar el fondo general. |
| `color.textPrimary` | `#F5F5F5` | Texto principal, acción primaria y señal sólida de live. |
| `color.textSecondary` | `#8C8C8E` | Cuerpo secundario, etiquetas y estado estimado. |
| `color.textTertiary` | `#9A9A9D` | Texto terciario y estado neutral. |

La paleta es deliberadamente oscura y de contraste alto. La variante clara es
futura; los componentes deben conservar semántica y contraste al cambiar de
tema.

## Tipografía

Fuente preferida: `SF Pro Display`/`SF Pro Text` en Apple; fallback `Inter`,
`system-ui`, sans-serif en otras plataformas. La implementación debe permitir
texto dinámico sin depender de una anchura fija.

| Token | Tamaño / peso | Tracking orientativo | Uso |
|---|---:|---:|---|
| `type.displayDecision` | `46 / 600` | `-1.2px` | Hora o decisión principal. |
| `type.metric` | `25 / 600` | `-0.5px` | Métrica principal. |
| `type.screenTitle` | `21 / 600` | `-0.4px` | Título de pantalla. |
| `type.label` | `15 / 600` | `-0.2px` | Etiquetas y acciones destacadas. |
| `type.body` | `15 / 400` | `-0.24px` | Copy funcional. |
| `type.secondary` | `13 / 400` | `-0.15px` | Contexto y explicación secundaria. |
| `type.overline` | `11 / 600` | `0.06em` a `0.12em` | Estados y categorías cortas, en mayúsculas. |

## Ritmo, radios y ergonomía

| Token | Valor | Uso |
|---|---:|---|
| `space.1` | `4px` | Separación de segmentos en barras. |
| `space.2` | `8px` | Gap entre chips y elementos compactos. |
| `space.3` | `12px` | Gap entre tarjetas y filas relacionadas. |
| `space.4` | `20px` | Margen lateral base de pantalla. |
| `space.5` | `26px` | Separación entre bloques. |
| `space.touch` | `44px` mínimo | Target táctil accesible. |
| `radius.banner` | `14px` | Banners y chips grandes. |
| `radius.card` | `16px` | Cards y superficies principales. |
| `radius.sheet` | `18px` | Hoja inferior y superficies modales. |
| `radius.pill` | `9999px` | Pills, inputs y CTA. |
| `height.pill` | `44–52px` | Botones tipo pill; no reducir el target táctil. |

## Componentes y estados

- CTA primario: pill de `color.textPrimary` sobre fondo oscuro; CTA
  secundario: contorno o superficie tenue.
- Card: `color.surfaceElevated`, sin sombra fuerte; mantener jerarquía por
  contraste, espaciado y forma.
- Banner de estado: contextual, recuperable y no modal para datos parciales,
  stale, degradados y errores.
- Chips: preferencia, línea y calidad; deben ser legibles con texto dinámico.
- Ruta: barra de composición para caminata, espera, transporte, transbordo y
  margen; lista vertical para pasos y paradas.
- Navegación: bottom navigation con tab activo de alto contraste y
  `Semantics` para tabs, botones, progreso y score.

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
