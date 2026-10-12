import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';

/// Velo degradado del prototipo (`.go-ov`).
class GetOffOverlay extends StatelessWidget {
  const GetOffOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x99F4F5F1),
              Color(0x00F4F5F1),
              Color(0x00F4F5F1),
              Color(0x99F4F5F1),
            ],
            stops: [0, .4, .72, 1],
          ),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
}

/// Tarjeta de bajada (`.go-card`): cae con `goIn` (0,7 s) y se sacude dos
/// veces (`shake`, 0,5 s con 0,75 s de retardo).
class GetOffCard extends StatefulWidget {
  const GetOffCard({
    super.key,
    required this.stop,
    required this.onAck,
    this.hint = 'Toca el timbre ahora',
  });

  final String stop;
  final String hint;
  final VoidCallback onAck;

  @override
  State<GetOffCard> createState() => _GetOffCardState();
}

class _GetOffCardState extends State<GetOffCard>
    with SingleTickerProviderStateMixin {
  static const _total = 1750; // ms
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _total),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (YgMotionScope.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _shake(double ms) {
    // Dos iteraciones de 500 ms que empiezan a los 750 ms.
    if (ms < 750) return 0;
    final p = ((ms - 750) % 500) / 500;
    const keys = <(double, double)>[
      (0, 0),
      (.2, -7),
      (.4, 7),
      (.6, -4),
      (.8, 3),
      (1, 0),
    ];
    for (var i = 0; i < keys.length - 1; i++) {
      final a = keys[i];
      final b = keys[i + 1];
      if (p <= b.$1) {
        final t = Curves.ease.transform((p - a.$1) / (b.$1 - a.$1));
        return a.$2 + (b.$2 - a.$2) * t;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final ms = _c.value * _total;
        final fall = const Cubic(.34, 1.35, .5, 1).transform((ms / 700).clamp(0.0, 1.0));
        return FractionalTranslation(
          translation: Offset(0, -1.3 * (1 - fall)),
          child: Transform.translate(offset: Offset(_shake(ms), 0), child: child),
        );
      },
      child: Semantics(
        liveRegion: true,
        container: true,
        label: 'Próxima parada, bájate: ${widget.stop}',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: YgColors.moss,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D1E2419),
                blurRadius: 48,
                offset: Offset(0, 24),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const GetOffBell(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRÓXIMA PARADA · BÁJATE',
                          style: YgText.overline.copyWith(color: YgColors.aloe),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.stop,
                          style: YgText.title2.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
                child: Text(
                  widget.hint,
                  style: const TextStyle(fontSize: 14, color: YgColors.aloe),
                ),
              ),
              YgButton(
                label: 'Entendido',
                variant: YgButtonVariant.inverse,
                size: YgButtonSize.lg,
                expand: true,
                onPressed: widget.onAck,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campana animada (`.bell`): anillo que pulsa (`bp`) y campana que suena
/// (`bring`). Con movimiento reducido queda estática.
class GetOffBell extends StatelessWidget {
  const GetOffBell({super.key});

  static double _ring(double t) {
    // keyframes de `bring` (grados): 0 %, 10 %, 20 %, 30 %, 40 %, 60 %.
    const keys = <(double, double)>[
      (0, 0),
      (.1, 16),
      (.2, -13),
      (.3, 9),
      (.4, -5),
      (.6, 0),
      (1, 0),
    ];
    for (var i = 0; i < keys.length - 1; i++) {
      final a = keys[i];
      final b = keys[i + 1];
      if (t <= b.$1) {
        final k = Curves.easeInOut.transform((t - a.$1) / (b.$1 - a.$1));
        return a.$2 + (b.$2 - a.$2) * k;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          YgLoop(
            duration: const Duration(milliseconds: 1600),
            builder: (context, t, _) {
              final k = Curves.easeOut.transform(t);
              return Positioned(
                left: -3,
                top: -3,
                right: -3,
                bottom: -3,
                child: Opacity(
                  opacity: (.9 * (1 - k)).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: .95 + .27 * k,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: YgColors.aloe.withValues(alpha: .6),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: YgColors.aloe,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: YgLoop(
              duration: const Duration(milliseconds: 1300),
              builder: (context, t, child) => Transform.rotate(
                angle: _ring(t) * math.pi / 180,
                alignment: const Alignment(0, -.76),
                child: child,
              ),
              child: const YgIcon(YgIcons.campana, size: 24, color: YgColors.moss),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pie de la alerta (`.go-foot`): qué sigue después de bajar.
class GetOffFoot extends StatelessWidget {
  const GetOffFoot({super.key, required this.text, this.emphasis});

  final String text;
  final String? emphasis;

  @override
  Widget build(BuildContext context) {
    return YgEnter(
      kind: YgEnterKind.up,
      delay: const Duration(milliseconds: 200),
      duration: const Duration(milliseconds: 600),
      child: YgGlass(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: YgText.sub.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                    children: [
                      TextSpan(text: text),
                      if (emphasis != null)
                        TextSpan(
                          text: emphasis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
