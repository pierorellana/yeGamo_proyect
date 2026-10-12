# ADR-009: Baseline visual «Bosque claro» y mapa persistente en Flutter

- **Estado:** accepted
- **Fecha:** 2026-10-12
- **Tipo:** complementaria (amplía [ADR-003](ADR-003-flutter-modular-architecture.md))
- **Ámbito:** App Flutter, sistema de diseño, mapa y movimiento

## Contexto

La primera implementación Flutter siguió una versión oscura del prototipo
(`yeGamo Prototype.html`, paleta `#0C0C0C`/`#235E5D`). El prototipo vigente,
`yeGamo-prototipo.html` con su paquete `yeGamo-prototipo-completo.zip`, define
otra identidad: tema claro «Bosque claro», símbolo G-recorrido, mapa de
Guayaquil con cámara 3D, panel inferior de tres alturas, ilustraciones, 43
iconos propios y un catálogo de 55 keyframes. La app no coincidía con él.

## Decisión

1. **Tema claro como baseline.** Los tokens (`yg_tokens.dart`) reproducen la
   paleta, tipografía, radios, tamaños y curvas del prototipo. El modo oscuro
   queda como variante futura. Fuente: la del sistema en Apple y Geist
   (OFL, empaquetada en `assets/fonts/`) en el resto.
2. **Iconos e ilustraciones como SVG/PNG del prototipo**, renderizados con
   `flutter_svg`; no se usan `Icons.*` de Material donde el prototipo define un
   icono.
3. **Mapa persistente bajo el `Navigator`** (`YgMapHost`): cada pantalla con
   mapa es transparente y declara su cámara con `YgMapBinding`, de modo que la
   cámara se desliza entre pantallas como en el prototipo. Las rutas no añaden
   transición propia; cada pantalla se anima con `YgEnter`.
4. **Honestidad de datos intacta.** El mapa base se dibuja siempre; rutas,
   vehículos y paradas simuladas del prototipo solo se dibujan con
   `AppConfig.demoDataEnabled` (ADR-008) y nunca se presentan como datos
   reales ni como `LIVE`. Los textos y cifras del prototipo no se hardcodean:
   la UI se enlaza a los view models y repositorios existentes.
5. **Movimiento reducido** apaga cámara 3D, vuelos, pulsos y bucles y deja
   fundidos de 120 ms.

## Consecuencias

- Se añade la dependencia `flutter_svg` y las fuentes Geist.
- La arquitectura `env/modules/shared`, Provider, rutas nombradas, la baseline
  de 17 pantallas y 9 estados UX y los contratos API no cambian.
- `context/specs/25_DESIGN_SYSTEM.md` y `context/prototype/DESIGN-TOKENS.md`
  se actualizan a la paleta clara.
