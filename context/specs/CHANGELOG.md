# Changelog

## 1.1.4 - 2026-10-12
- La app Flutter adopta el prototipo vigente `yeGamo-prototipo.html`: tema
  claro «Bosque claro», símbolo G-recorrido, 43 iconos SVG propios,
  ilustraciones, mapa de Guayaquil con cámara 3D persistente, panel inferior de
  tres alturas y el catálogo de animaciones (ADR-009).
- `25_DESIGN_SYSTEM.md` y `prototype/DESIGN-TOKENS.md` sustituyen la paleta
  oscura por la clara; el modo oscuro queda como variante futura.
- Sin cambios de contrato API, de baseline (17 pantallas, 9 estados) ni de
  reglas de honestidad de datos.

## 1.1.3 - 2026-10-12
- Cierre verificable de la baseline Flutter: catálogo test-only de 17
  pantallas y 9 estados, integración de primer inicio a retención y checks de
  semántica/responsive sin imágenes golden no soportadas por el proyecto.
- Contract test OpenAPI ampliado para comparar operaciones publicadas con
  controllers, campos, estados, headers, ejemplos y errores canónicos.
- Las operaciones de comunidad permanecen explícitamente `post-mvp`; no se
  declaran implementadas en runtime.
- Se documentan comandos ejecutados, límites externos y precondiciones reales
  en `context/plans/RESTRUCTURE-CLOSEOUT.md`.

## 1.1.2 - 2026-10-12
- ADR-008 fija el MVP sin proveedor autorizado de transporte o
  geocodificación y separa `PROVIDER_UNAVAILABLE` de
  `LOCATION_OUT_OF_COVERAGE`.
- Fixtures de `DemoTransitProvider` y del prototipo quedan restringidos a una
  configuración explícita de desarrollo, pruebas o demo; no pueden declarar
  `LIVE` ni convertirse en fuente productiva.
- Contrato canónico y copia derivada alineados con `503`, `UNAVAILABLE`,
  `X-Trace-Id` y metadatos de fuente nulos/falsos cuando no hay provider.
- `arrived` y `nocov` quedan documentados como estados dentro de la baseline
  de 17 pantallas y 9 estados UX.

## 1.1.1 - 2026-10-02
- Normalizacion de la arquitectura Flutter a `env/modules/shared` con
  `provider`, `ChangeNotifier`, `MultiProvider`, rutas nombradas y un servicio
  HTTP compartido.
- Ampliacion del modelo de dominio para eventos, preferencias, dispositivos,
  entregas, exportaciones y salud de proveedores.
- Ampliacion del contrato API con identidad, migracion idempotente de invitado,
  dispositivos y operaciones faltantes del MVP.
- `14_SCHEMA.sql` marcado como referencia derivada de migraciones versionadas.
- Manifest actualizado a la baseline normalizada 1.1.1.

## 1.1 - 2026-10-02
- Rebranding RutaYa -> yeGamo.
- Alineacion funcional con prototipo navegable.
- 17 pantallas formalizadas.
- 9 estados UX formalizados.
- Rutinas y Avisos integrados al alcance MVP.
- API ampliada con alerts, notifications y preferences.
- Trazabilidad pantalla -> RF.
- Baseline de sistema visual y marca.
- Aclaracion de datos mock y de la referencia "Metrovia GTFS".
- Criterios de testing actualizados.

## 1.0 - 2026-09-19
- Baseline inicial de producto, negocio, integracion y arquitectura.
