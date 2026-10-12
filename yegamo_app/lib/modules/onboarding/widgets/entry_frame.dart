import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';

/// Lienzo de 390×844 del prototipo, escalado para encajar en la pantalla real
/// sin cambiar las proporciones (las pantallas de arranque están maquetadas
/// con coordenadas absolutas).
class ProtoFrame extends StatelessWidget {
  const ProtoFrame({super.key, required this.child});

  final Widget child;

  static const double width = 390;
  static const double height = 844;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(width: width, height: height, child: child),
    );
  }
}

/// Marca «G-recorrido + yeGamo» (`.brand`).
class EntryBrand extends StatelessWidget {
  const EntryBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        YgMark(size: 24),
        SizedBox(width: 8),
        Text(
          'yeGamo',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -.51,
            height: 1.4,
            color: YgColors.moss,
          ),
        ),
      ],
    );
  }
}

/// Estilo `.disp` del prototipo (cifras grandes).
TextStyle dispStyle(double size) => TextStyle(
  fontSize: size,
  fontWeight: FontWeight.w600,
  letterSpacing: -.04 * size,
  height: 1,
  color: YgColors.moss,
  fontFeatures: const [FontFeature.tabularFigures()],
);
