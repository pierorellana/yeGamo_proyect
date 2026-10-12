import 'package:flutter/material.dart';

import '../design_system/yg_components.dart';

/// Página opaca del prototipo (`.page`): fondo «Bosque claro», padding
/// 56/16/120 y desplazamiento vertical sin barra visible.
class YgPage extends StatelessWidget {
  const YgPage({super.key, required this.children, this.bottomPadding = 120});

  final List<Widget> children;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YgColors.page,
      body: YgBackground(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(
            context,
          ).copyWith(scrollbars: false),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              YgSpace.gutter,
              YgSize.topbarY,
              YgSpace.gutter,
              bottomPadding,
            ),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Fila de navegación (`.navrow`): alto 44, extremos opcionales.
class YgNavRow extends StatelessWidget {
  const YgNavRow({super.key, this.leading, this.title, this.trailing});

  final Widget? leading;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: YgSize.topbar,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ?leading,
          if (title != null)
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title!, style: YgText.largeTitle),
              ),
            )
          else
            const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Título de grupo (`.ovl.gh`): mayúsculas con margen 24/16/8.
class YgGroupHeader extends StatelessWidget {
  const YgGroupHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: YgOverline(text),
  );
}

/// Campo de texto con la estética de `.od` (fila blanca con borde).
class YgTextInput extends StatelessWidget {
  const YgTextInput({
    super.key,
    required this.controller,
    required this.label,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: YgColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: YgText.overline.copyWith(
              fontSize: 11,
              letterSpacing: 0,
              fontWeight: FontWeight.w400,
            ),
          ),
          TextField(
            controller: controller,
            autofocus: autofocus,
            cursorColor: YgColors.cypress,
            style: YgText.sub.copyWith(color: YgColors.text),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Contenedor de hoja modal con cabecera `.mhead` y relleno de teclado.
class YgSheetBody extends StatelessWidget {
  const YgSheetBody({
    super.key,
    required this.title,
    required this.children,
    this.leftLabel,
    this.onLeft,
    this.rightLabel,
    this.onRight,
  });

  final String title;
  final String? leftLabel;
  final VoidCallback? onLeft;
  final String? rightLabel;
  final VoidCallback? onRight;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            YgModalHeader(
              title: title,
              leftLabel: leftLabel,
              onLeft: onLeft,
              rightLabel: rightLabel,
              onRight: onRight,
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Confirmación en hoja modal (reemplaza al `AlertDialog`).
Future<bool> showYgConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Volver',
  bool destructive = false,
}) async {
  final result = await showYgModalSheet<bool>(
    context,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: YgText.title2),
          const SizedBox(height: 8),
          Text(message, style: YgText.secondary),
          const SizedBox(height: 16),
          YgButton(
            label: confirmLabel,
            expand: true,
            variant: destructive
                ? YgButtonVariant.danger
                : YgButtonVariant.primary,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: 8),
          YgButton(
            label: cancelLabel,
            expand: true,
            variant: YgButtonVariant.ghost,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Entrada `rise` escalonada sin temporizadores: el retraso (50 ms por
/// posición, tope 300 ms) se codifica en la curva para no dejar `Timer`s
/// pendientes al desmontar la página.
Widget ygRise(Widget child, {int index = 0}) {
  final delay = (index < 6 ? index : 6) * 50;
  if (delay == 0) return YgEnter(child: child);
  final total = 500 + delay;
  return YgEnter(
    duration: Duration(milliseconds: total),
    curve: Interval(delay / total, 1, curve: YgMotion.easeOut),
    child: child,
  );
}
