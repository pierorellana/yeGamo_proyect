import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design_system/yg_components.dart';
import '../models/data_state.dart';
import 'yg_float.dart';

/// Vista de estado de datos (E1–E8 del prototipo).
///
/// - `error`, `empty`, `permission`, `noCoverage`: bloque `.state` con
///   ilustración `.ill` de 120 px.
/// - `offline`, `stale`, `degraded`: banner `.banner` (`off`/`warn`) con
///   acción de reintento.
/// - `loading`: cabecera `.ld-head` con anillo `ld-ring`.
class RemoteStateView extends StatelessWidget {
  const RemoteStateView({
    super.key,
    required this.state,
    this.child,
    this.onRetry,
  });

  final UxState state;
  final Widget? child;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (state == UxState.ok && child != null) return child!;

    final copy = _copyFor(state);
    final retry = onRetry != null && copy.canRetry ? onRetry : null;

    final Widget content = switch (state) {
      UxState.loading => _LoadingHead(title: copy.title, message: copy.message),
      UxState.offline || UxState.stale || UxState.degraded => YgBanner(
        title: copy.title,
        message: copy.message,
        icon: copy.icon,
        tone: state == UxState.offline ? YgBannerTone.off : YgBannerTone.warn,
        actionLabel: retry == null ? null : 'Reintentar',
        onAction: retry,
      ),
      _ => _StateBlock(copy: copy, state: state, onRetry: retry),
    };

    return Semantics(
      container: true,
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: YgEnter(child: content),
        ),
      ),
    );
  }

  static _StateCopy _copyFor(UxState state) => switch (state) {
    UxState.ok => const _StateCopy(
      title: 'Listo',
      message: 'No hay contenido para mostrar.',
      icon: YgIcons.check,
      canRetry: false,
    ),
    UxState.loading => const _StateCopy(
      title: 'Cargando',
      message: 'Estamos consultando información actualizada.',
      icon: YgIcons.reloj,
      canRetry: false,
    ),
    UxState.empty => const _StateCopy(
      title: 'Sin resultados',
      message: 'Prueba con otra búsqueda o modifica tus criterios.',
      icon: YgIcons.buscar,
      canRetry: false,
      overline: 'Sin opciones',
    ),
    UxState.error => const _StateCopy(
      title: 'No se pudo cargar',
      message: 'Intenta nuevamente o vuelve a una superficie segura.',
      icon: YgIcons.alerta,
      canRetry: true,
      overline: 'Error del servicio',
    ),
    UxState.offline => const _StateCopy(
      title: 'Sin conexión',
      message: 'No hay red. El cache se identificará como offline.',
      icon: YgIcons.sinConexion,
      canRetry: true,
    ),
    UxState.stale => const _StateCopy(
      title: 'Datos desactualizados',
      message: 'La información puede haber cambiado.',
      icon: YgIcons.reloj,
      canRetry: true,
    ),
    UxState.degraded => const _StateCopy(
      title: 'Datos degradados',
      message: 'La fuente disponible es limitada o no está disponible.',
      icon: YgIcons.alerta,
      canRetry: true,
    ),
    UxState.permission => const _StateCopy(
      title: 'Permiso de ubicación necesario',
      message: 'Puedes continuar usando un origen manual.',
      icon: YgIcons.ubicacionDesactivada,
      canRetry: false,
      overline: 'Origen manual',
    ),
    UxState.noCoverage => const _StateCopy(
      title: 'Sin cobertura',
      message: 'No encontramos una fuente autorizada para esta zona.',
      icon: YgIcons.ubicacionDesactivada,
      canRetry: false,
      overline: 'Fuera de zona',
    ),
  };
}

class _StateCopy {
  const _StateCopy({
    required this.title,
    required this.message,
    required this.icon,
    required this.canRetry,
    this.overline,
  });

  final String title;
  final String message;
  final String icon;
  final bool canRetry;
  final String? overline;
}

/// Bloque `.state`: ilustración, sobrelínea, título, mensaje y acción.
class _StateBlock extends StatelessWidget {
  const _StateBlock({
    required this.copy,
    required this.state,
    required this.onRetry,
  });

  final _StateCopy copy;
  final UxState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isError = state == UxState.error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Illustration(state: state, icon: copy.icon),
        const SizedBox(height: 8),
        if (copy.overline != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: YgOverline(
              copy.overline!,
              color: isError ? YgColors.clay : null,
            ),
          ),
        Text(copy.title, style: YgText.title2),
        const SizedBox(height: 8),
        Text(copy.message, style: YgText.secondary),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          YgButton(
            label: 'Reintentar',
            icon: YgIcons.reintentar,
            expand: true,
            onPressed: onRetry,
          ),
        ],
      ],
    );
  }
}

/// `.ill`: 120 px, fondo #F4F5F1, radio 20 y flotación 3D.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.state, required this.icon});

  final UxState state;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final Widget art = switch (state) {
      UxState.error => Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          SvgPicture.asset(
            'assets/ilustraciones/error-ruta.svg',
            width: 280,
            height: 110,
            excludeFromSemantics: true,
          ),
          const Positioned(
            top: 34 - 5,
            left: 0,
            right: 0,
            child: Center(child: _WobblyBus()),
          ),
        ],
      ),
      UxState.empty => SvgPicture.asset(
        'assets/ilustraciones/vacio-busqueda.svg',
        width: 200,
        height: 112,
        excludeFromSemantics: true,
      ),
      _ => Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: YgColors.border),
        ),
        child: YgIcon(
          icon,
          size: 26,
          color: state == UxState.noCoverage ? YgColors.clay : YgColors.cypress,
        ),
      ),
    };
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: YgColors.page,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: YgFloat(lift: 3, child: art),
    );
  }
}

/// `.ill-bus`: píldora punteada que oscila (`wob`) con signo de alerta.
/// No muestra un ETA: el servicio falló y no se inventan tiempos.
class _WobblyBus extends StatelessWidget {
  const _WobblyBus();

  @override
  Widget build(BuildContext context) {
    return YgLoop(
      duration: const Duration(milliseconds: 2400),
      builder: (context, t, child) {
        // 0 %: 0°, 30 %: −4°, 60 %: 3°, 100 %: 0°.
        final deg = t < .3
            ? -4 * (t / .3)
            : t < .6
            ? -4 + 7 * ((t - .3) / .3)
            : 3 * (1 - (t - .6) / .4);
        return Transform.rotate(angle: deg * math.pi / 180, child: child);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IntrinsicWidth(
            child: SizedBox(
              height: 28,
              child: YgDashedBox(
            radius: 14,
            color: YgColors.clay,
            minWidth: 52,
            minHeight: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: const YgIcon(YgIcons.bus, size: 16, color: YgColors.clay),
              ),
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: YgColors.clay,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.ld-head`: anillo de carga 48 + título y mensaje.
class _LoadingHead extends StatelessWidget {
  const _LoadingHead({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _LoadRing(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: YgText.title2),
              const SizedBox(height: 2),
              Text(message, style: YgText.secondary),
            ],
          ),
        ),
      ],
    );
  }
}

/// `.ld-ring`: 48 px, pista #E6E9E0 y cabeza cypress girando 1,1 s.
class _LoadRing extends StatelessWidget {
  const _LoadRing();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: YgColors.fill2,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: YgLoop(
              duration: const Duration(milliseconds: 1100),
              builder: (context, t, _) => Transform.rotate(
                angle: t * 2 * math.pi,
                child: const CustomPaint(painter: _RingPainter()),
              ),
            ),
          ),
          const YgIcon(YgIcons.bus, size: 20, color: YgColors.cypress),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width * 20 / 48,
    );
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, p..color = YgColors.track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * .26,
      false,
      p..color = YgColors.cypress,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
