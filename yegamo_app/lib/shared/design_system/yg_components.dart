import 'package:flutter/material.dart';

import 'yg_controls.dart';
import 'yg_feedback.dart';
import 'yg_icon.dart';

export 'yg_controls.dart';
export 'yg_feedback.dart';
export 'yg_icon.dart';
export 'yg_motion.dart';
export 'yg_sheet.dart';
export 'yg_surfaces.dart';
export 'yg_tokens.dart';

/// Botón primario (compatibilidad): píldora moss de 48.
class YgPrimaryButton extends StatelessWidget {
  const YgPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;

  @override
  Widget build(BuildContext context) =>
      YgButton(label: label, onPressed: onPressed, icon: icon, expand: true);
}

/// Botón secundario (compatibilidad): píldora tenue de 48.
class YgSecondaryButton extends StatelessWidget {
  const YgSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;

  @override
  Widget build(BuildContext context) => YgButton(
    label: label,
    onPressed: onPressed,
    icon: icon,
    expand: true,
    variant: YgButtonVariant.secondary,
  );
}

/// Banner de estado (compatibilidad): usa el banner del sistema.
class YgStatusBanner extends StatelessWidget {
  const YgStatusBanner({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return YgBanner(
      title: message,
      icon: YgIcons.alerta,
      tone: YgBannerTone.off,
    );
  }
}
