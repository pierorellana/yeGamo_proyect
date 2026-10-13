import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';

/// Barra superior flotante de las pantallas con mapa (`.topbar`): botón de
/// volver, píldora de vidrio centrada con título y subtítulo, y una acción
/// opcional a la derecha (o un hueco de 44 px para mantener el centrado).
class YgMapTopRow extends StatelessWidget {
  const YgMapTopRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.trailingIcon,
    this.trailingLabel,
    this.onTrailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final String? trailingIcon;
  final String? trailingLabel;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: YgSize.topbarY,
      left: 16,
      right: 16,
      child: YgEnter(
        kind: YgEnterKind.fade,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Tooltip(
              message: 'Volver',
              child: YgIconButton(
                icon: YgIcons.atras,
                style: YgIconButtonStyle.secondary,
                semanticLabel: 'Volver',
                onPressed: onBack,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 236),
                child: YgGlass(
                  radius: 22,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  blur: 0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: YgText.sub.copyWith(fontSize: 14, height: 1.2),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: YgText.meta.copyWith(height: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (trailingIcon != null)
              Tooltip(
                message: trailingLabel ?? '',
                child: YgIconButton(
                  icon: trailingIcon!,
                  style: YgIconButtonStyle.secondary,
                  semanticLabel: trailingLabel ?? '',
                  onPressed: onTrailing,
                ),
              )
            else
              const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }
}
