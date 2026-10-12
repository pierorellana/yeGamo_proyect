import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/models/data_state.dart';
import '../../nearby/models/nearby_models.dart';
import '../../nearby/widgets/freshness_label.dart';
import '../../nearby/widgets/nearby_widgets.dart';

/// Cabecera flotante del Inicio (`.hdr`): píldora de ubicación + avisos +
/// cuenta.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.locationLabel,
    required this.locationName,
    required this.unread,
    required this.onLocation,
    required this.onNotices,
    required this.onSettings,
  });

  final String locationLabel;
  final String locationName;
  final int unread;
  final VoidCallback onLocation;
  final VoidCallback onNotices;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: YgSize.topbarY,
      left: 16,
      right: 16,
      child: YgEnter(
        kind: YgEnterKind.fade,
        duration: const Duration(milliseconds: 600),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: YgPressable(
                onTap: onLocation,
                semanticLabel: 'Buscar destino',
                child: YgGlass(
                  radius: 22,
                  height: 44,
                  padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: YgColors.border),
                        ),
                        child: const YgMark(size: 22),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              locationLabel,
                              maxLines: 1,
                              style: YgText.meta.copyWith(
                                fontSize: 11,
                                height: 1.2,
                                color: YgColors.text3,
                              ),
                            ),
                            Text(
                              locationName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: YgText.sub.copyWith(
                                fontSize: 14,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Avisos',
                  child: YgIconButton(
                    key: const ValueKey('home_notices'),
                    icon: YgIcons.campana,
                    semanticLabel: 'Avisos',
                    badge: unread,
                    onPressed: onNotices,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Ajustes',
                  child: YgIconButton(
                    key: const ValueKey('home_settings'),
                    icon: YgIcons.usuario,
                    semanticLabel: 'Ajustes y cuenta',
                    onPressed: onSettings,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado visible de la próxima salida. El contrato de Inicio todavía no
/// entrega una hora calculada: se muestra el estado honesto, nunca una hora.
class HomeDepartureCopy {
  const HomeDepartureCopy({
    required this.message,
    this.label,
    this.title = 'Próxima salida',
  });

  final String title;
  final String message;
  final Widget? label;

  static HomeDepartureCopy forState(UxState state, {required bool located}) {
    final title = located ? 'Próxima salida' : 'Desde tu origen';
    return switch (state) {
      UxState.loading => HomeDepartureCopy(
        title: title,
        message: 'Consultando información actualizada…',
        label: const YgEstLabel(text: 'Consultando'),
      ),
      UxState.offline => HomeDepartureCopy(
        title: title,
        message:
            'Sin conexión. No mostramos horarios sin una fuente actual.',
        label: const YgSchedLabel(text: 'Sin conexión'),
      ),
      UxState.stale => HomeDepartureCopy(
        title: title,
        message: 'Los datos pueden haber cambiado. Reintenta para actualizar.',
        label: const YgEstLabel(text: 'Desactualizado'),
      ),
      UxState.degraded => HomeDepartureCopy(
        title: title,
        message:
            'La fuente disponible es limitada. No estimamos horarios sin '
            'datos confiables.',
        label: const YgEstLabel(text: 'Datos limitados'),
      ),
      UxState.error => HomeDepartureCopy(
        title: title,
        message: 'No pudimos cargar la información. Inténtalo de nuevo.',
      ),
      _ => HomeDepartureCopy(
        title: title,
        message:
            'Aún no hay una salida calculada. Planifica un viaje y te '
            'mostramos a qué hora salir.',
      ),
    };
  }
}

/// Tarjeta principal de la próxima salida (`.hero3d`).
class HomeHero extends StatelessWidget {
  const HomeHero({
    super.key,
    required this.copy,
    required this.onPlan,
    this.onRetry,
  });

  final HomeDepartureCopy copy;
  final VoidCallback onPlan;

  /// Si existe, se muestra el botón circular «Reintentar» junto a la acción
  /// principal (equivale al botón de aviso del prototipo).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            YgOverline(copy.title),
            if (copy.label != null) copy.label!,
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              label: 'Sin hora de salida calculada',
              excludeSemantics: true,
              child: Text(
                '--:--',
                style: YgText.summaryTime.copyWith(color: YgColors.muted),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Sal en',
                  style: YgText.meta.copyWith(color: YgColors.text3),
                ),
                const SizedBox(height: 2),
                Text(
                  '— min',
                  style: YgText.sub.copyWith(
                    fontSize: 17,
                    letterSpacing: -.34,
                    color: YgColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
          child: Text(copy.message, style: YgText.secondary),
        ),
        Row(
          children: [
            Expanded(
              child: YgButton(
                key: const ValueKey('home_planner'),
                label: 'Planificar un viaje',
                expand: true,
                onPressed: onPlan,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: 'Reintentar',
                child: YgIconButton(
                  key: const ValueKey('home_retry'),
                  icon: YgIcons.reintentar,
                  style: YgIconButtonStyle.secondary,
                  size: 48,
                  semanticLabel: 'Reintentar',
                  onPressed: onRetry,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Contenido del panel en estado mínimo (`.peek`).
class HomePeek extends StatelessWidget {
  const HomePeek({super.key, required this.copy, required this.onPlan});

  final HomeDepartureCopy copy;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                YgOverline(copy.title),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '--:--',
                      style: YgText.summaryTime.copyWith(
                        fontSize: 28,
                        letterSpacing: -1.12,
                        color: YgColors.muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Sin salida calculada',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: YgText.secondary.copyWith(
                          fontWeight: FontWeight.w600,
                          color: YgColors.cypress,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          YgButton(
            key: const ValueKey('home_planner'),
            label: 'Planificar',
            size: YgButtonSize.sm,
            onPressed: onPlan,
          ),
        ],
      ),
    );
  }
}

/// Tarjeta «Sin ubicación, sin problema» (`.pcard`).
class HomePermissionCard extends StatelessWidget {
  const HomePermissionCard({
    super.key,
    required this.onChooseOrigin,
    required this.onEnable,
  });

  final VoidCallback onChooseOrigin;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(YgRadius.card),
        border: Border.all(color: YgColors.border),
        boxShadow: YgShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PermissionIllustration(),
          const SizedBox(height: 12),
          const Text('Sin ubicación, sin problema', style: YgText.title),
          const SizedBox(height: 4),
          Text(
            'Elige un punto de partida o activa la ubicación para ver lo que '
            'tienes cerca.',
            style: YgText.secondary.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              YgButton(
                key: const ValueKey('home_choose_origin'),
                label: 'Elegir origen',
                size: YgButtonSize.sm,
                onPressed: onChooseOrigin,
              ),
              const SizedBox(width: 8),
              YgButton(
                key: const ValueKey('home_enable_location'),
                label: 'Activar ubicación',
                size: YgButtonSize.sm,
                variant: YgButtonVariant.secondary,
                onPressed: onEnable,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PermissionIllustration extends StatelessWidget {
  const _PermissionIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          YgLoop(
            duration: const Duration(seconds: 14),
            builder: (context, t, _) => Transform.rotate(
              angle: t * 2 * math.pi,
              child: const SizedBox(
                width: 64,
                height: 64,
                child: CustomPaint(painter: _DashedRingPainter()),
              ),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: YgColors.moss,
              shape: BoxShape.circle,
            ),
            child: const YgIcon(
              YgIcons.ubicacionDesactivada,
              size: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = YgColors.moss.withValues(alpha: .06)
      ..strokeWidth = 1;
    for (var y = 15.0; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y + .5), Offset(size.width, y + .5), paint);
    }
    for (var x = 15.0; x < size.width; x += 16) {
      canvas.drawLine(Offset(x + .5, 0), Offset(x + .5, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = YgColors.olive
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final r = size.width / 2 - .75;
    final circumference = 2 * math.pi * r;
    const dash = 4.0;
    const gap = 3.0;
    final count = (circumference / (dash + gap)).floor();
    final step = 2 * math.pi / count;
    for (var i = 0; i < count; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: size.center(Offset.zero), radius: r),
        i * step,
        step * dash / (dash + gap),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Campo falso «¿A dónde vas?» (`.sf`).
class HomeSearchField extends StatelessWidget {
  const HomeSearchField({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return YgPressable(
      onTap: onTap,
      semanticLabel: 'Buscar un lugar',
      child: Container(
        key: const ValueKey('home_search'),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: YgColors.fill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            YgIcon(YgIcons.buscar, size: 20, color: YgColors.text3),
            SizedBox(width: 8),
            Text(
              '¿A dónde vas?',
              style: TextStyle(fontSize: 15, color: YgColors.text3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de parada cercana del carrusel (`.ncard`).
class HomeNearCard extends StatelessWidget {
  const HomeNearCard({super.key, required this.stop, required this.onTap});

  final NearbyStop stop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 248,
      child: YgCard(
        onTap: onTap,
        semanticLabel: stop.name,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const YgTile(icon: YgIcons.bus),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: YgText.sub.copyWith(letterSpacing: -.15),
                      ),
                      Text(
                        nearbyDistanceLabel(stop),
                        style: YgText.meta.copyWith(color: YgColors.text3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: YgFreshnessLabel(stop.dataState),
            ),
          ],
        ),
      ),
    );
  }
}
