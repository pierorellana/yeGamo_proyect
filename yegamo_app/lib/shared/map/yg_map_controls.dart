import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design_system/yg_components.dart';
import 'yg_map_view.dart';

/// Columna de controles del mapa (`.mctl`): zoom +/−, centrar y ver recorrido
/// completo. Se coloca sobre el panel inferior y sigue su altura.
class YgMapControls extends StatelessWidget {
  const YgMapControls({
    super.key,
    required this.sheetHeight,
    required this.sheetBottom,
    this.fitSelected = false,
    this.onFit,
    this.hidden = false,
  });

  final double sheetHeight;
  final double sheetBottom;
  final bool fitSelected;
  final VoidCallback? onFit;

  /// Oculto en estado máximo del panel o si no hay espacio libre.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final bottom = sheetBottom + sheetHeight + 12;
    final show = !hidden && (h - bottom - 192) >= 112;
    final ctl = context.read<YgMapScope>().controller;
    return Positioned(
      right: 16,
      bottom: bottom,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: IgnorePointer(
          ignoring: !show,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              YgGlass(
                radius: 22,
                width: 44,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Btn(
                      icon: YgIcons.mas,
                      label: 'Acercar',
                      onTap: () => ctl.zoomBy(1.4),
                    ),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: YgColors.borderStrong,
                    ),
                    _Btn(
                      icon: YgIcons.menos,
                      label: 'Alejar',
                      onTap: () => ctl.zoomBy(1 / 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              YgIconButton(
                icon: YgIcons.navegar,
                semanticLabel: 'Centrar en mi ubicación',
                onPressed: ctl.reset,
              ),
              const SizedBox(height: 8),
              YgIconButton(
                icon: YgIcons.recorridoCompleto,
                semanticLabel: 'Ver recorrido completo',
                selected: fitSelected,
                onPressed: onFit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.label, required this.onTap});

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return YgPressable(
      onTap: onTap,
      semanticLabel: label,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(child: YgIcon(icon, size: 20, color: YgColors.moss)),
      ),
    );
  }
}
