import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/map/yg_map_host.dart';
import '../../../shared/map/yg_map_view.dart';
import '../../nearby/widgets/map_top_row.dart';

/// Pantalla «Sin cobertura» (19-sin-cobertura): mapa en modo `nocov`, barra
/// superior «Fuera de cobertura» y panel fijo de 328 px.
///
/// Se muestra cuando el origen o destino cae fuera de la zona con fuente
/// autorizada (`UxState.noCoverage` / `LOCATION_OUT_OF_COVERAGE`). No estima
/// horarios: solo explica el límite y ofrece cambiar el destino.
///
/// Devuelve contenido para un `Stack`/`Scaffold` transparente; la página que
/// lo aloja decide la navegación mediante [onBack] y [onChangeDestination].
/// [onNotify] es opcional: solo se muestra «Avisarme cuando esté disponible»
/// si existe un servicio real que registre ese aviso.
class NoCoverageView extends StatelessWidget {
  const NoCoverageView({
    super.key,
    required this.onBack,
    required this.onChangeDestination,
    this.destination,
    this.onNotify,
    this.notifyLabel = 'Avisarme cuando esté disponible',
    this.zoneLabel = 'Zona disponible: Guayaquil',
  });

  static const double sheetHeight = 328;

  final VoidCallback onBack;
  final VoidCallback onChangeDestination;
  final String? destination;
  final VoidCallback? onNotify;
  final String notifyLabel;
  final String zoneLabel;

  @override
  Widget build(BuildContext context) {
    final name = (destination ?? '').trim();
    final target = name.isEmpty ? 'esta zona' : name;
    return YgMapBinding(
      view: YgMapView(
        mode: YgMapMode.nocov,
        visibleBottom: 844 - 8 - sheetHeight - 16,
        tags: name.isEmpty ? const <String>[] : <String>[name],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          YgMapTopRow(
            title: 'Fuera de cobertura',
            subtitle: zoneLabel,
            onBack: onBack,
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: YgEnter(
              kind: YgEnterKind.up,
              child: _FixedSheet(
                height: sheetHeight,
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(
                        height: 24,
                        child: Center(child: _Grabber()),
                      ),
                      Expanded(
                        child: YgStagger(
                          spacing: 0,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const YgTile(
                                        icon: YgIcons.ubicacionDesactivada,
                                        tone: YgTileTone.clay,
                                      ),
                                      const SizedBox(width: 8),
                                      const YgOverline(
                                        'Sin cobertura',
                                        color: YgColors.clay,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Aún no llegamos a $target',
                                    style: YgText.title2,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Por ahora yeGamo planifica viajes dentro '
                                    'de Guayaquil. No estimamos horarios sin '
                                    'datos confiables.',
                                    style: YgText.secondary.copyWith(
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            YgButton(
                              key: const ValueKey('no_coverage_change'),
                              label: 'Cambiar destino',
                              size: YgButtonSize.lg,
                              expand: true,
                              onPressed: onChangeDestination,
                            ),
                            if (onNotify != null) ...[
                              const SizedBox(height: 8),
                              YgButton(
                                key: const ValueKey('no_coverage_notify'),
                                label: notifyLabel,
                                variant: YgButtonVariant.ghost,
                                expand: true,
                                onPressed: onNotify,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 5,
    decoration: BoxDecoration(
      color: YgColors.handle,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

/// Superficie del panel inferior (`.sheet`) con altura fija.
class _FixedSheet extends StatelessWidget {
  const _FixedSheet({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(YgRadius.sheet);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: YgShadows.sheet),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: r,
              border: Border.all(
                color: YgColors.moss.withValues(alpha: .08),
                width: .5,
              ),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xF7FFFFFF), Color(0xF7FFFFFF), Color(0xF7F6F8F2)],
                stops: [0, .55, 1],
              ),
            ),
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}
