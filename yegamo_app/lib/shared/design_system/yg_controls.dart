import 'package:flutter/material.dart';

import 'yg_icon.dart';
import 'yg_motion.dart';
import 'yg_surfaces.dart';
import 'yg_tokens.dart';

enum YgButtonVariant { primary, go, secondary, ghost, inverse, danger }

enum YgButtonSize { lg, md, sm }

/// Botón píldora del sistema: 56 (entrada), 48 (estándar) y 36 (en línea).
class YgButton extends StatelessWidget {
  const YgButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = YgButtonVariant.primary,
    this.size = YgButtonSize.md,
    this.expand = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final YgButtonVariant variant;
  final YgButtonSize size;
  final bool expand;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final (h, fs, px, ic) = switch (size) {
      YgButtonSize.lg => (YgSize.buttonLg, 16.0, 24.0, 18.0),
      YgButtonSize.md => (YgSize.buttonMd, 15.0, 20.0, 18.0),
      YgButtonSize.sm => (YgSize.buttonSm, 14.0, 16.0, 16.0),
    };
    final (bg, fg) = switch (variant) {
      YgButtonVariant.primary => (YgColors.moss, Colors.white),
      YgButtonVariant.go => (YgColors.cypress, Colors.white),
      YgButtonVariant.secondary => (YgColors.fill, YgColors.moss),
      YgButtonVariant.ghost => (Colors.transparent, YgColors.cypress),
      YgButtonVariant.inverse => (Colors.white, YgColors.moss),
      YgButtonVariant.danger => (const Color(0x1A9C4F3A), YgColors.clay),
    };
    final shadow = size == YgButtonSize.sm
        ? null
        : switch (variant) {
            YgButtonVariant.primary => YgShadows.pri,
            YgButtonVariant.go => YgShadows.go,
            _ => null,
          };
    final enabled = onPressed != null;
    final content = Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: px),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(h / 2),
        boxShadow: enabled ? shadow : null,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            YgIcon(icon!, size: ic, color: fg),
            SizedBox(width: size == YgButtonSize.sm ? 6 : 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fs,
                fontWeight: FontWeight.w600,
                letterSpacing: -.15,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
    return Opacity(
      opacity: enabled ? 1 : .4,
      child: YgPressable(
        onTap: onPressed,
        semanticLabel: semanticLabel ?? label,
        child: content,
      ),
    );
  }
}

enum YgIconButtonStyle { glass, secondary, plain, dark }

/// Botón de icono 44 (o 36) con insignia opcional.
class YgIconButton extends StatelessWidget {
  const YgIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.style = YgIconButtonStyle.glass,
    this.size = YgSize.iconButton,
    this.iconSize,
    this.badge = 0,
    this.selected = false,
    this.color,
  });

  final String icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final YgIconButtonStyle style;
  final double size;
  final double? iconSize;
  final int badge;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isc = iconSize ?? (size <= 36 ? 16.0 : 20.0);
    final fg = color ??
        ((style == YgIconButtonStyle.dark || selected)
            ? Colors.white
            : YgColors.moss);
    Widget body = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Center(child: YgIcon(icon, size: isc, color: fg)),
          if (badge > 0) Positioned(top: 6, right: 6, child: YgBadge(badge)),
        ],
      ),
    );
    final r = size / 2;
    body = switch (style) {
      YgIconButtonStyle.glass when !selected => YgGlass(
        radius: r,
        child: body,
      ),
      YgIconButtonStyle.secondary => DecoratedBox(
        decoration: BoxDecoration(
          color: YgColors.fill,
          borderRadius: BorderRadius.circular(r),
        ),
        child: body,
      ),
      YgIconButtonStyle.dark => DecoratedBox(
        decoration: BoxDecoration(
          color: YgColors.moss,
          borderRadius: BorderRadius.circular(r),
        ),
        child: body,
      ),
      _ when selected => DecoratedBox(
        decoration: BoxDecoration(
          color: YgColors.moss,
          borderRadius: BorderRadius.circular(r),
          boxShadow: YgShadows.glass,
        ),
        child: body,
      ),
      _ => body,
    };
    return YgPressable(
      onTap: onPressed,
      semanticLabel: semanticLabel,
      child: body,
    );
  }
}

/// Insignia numérica (`.badge`).
class YgBadge extends StatelessWidget {
  const YgBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: YgColors.moss,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

/// Chip de 32 de alto (`.chip`).
class YgChip extends StatelessWidget {
  const YgChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.height = YgSize.chip,
  });

  final String label;
  final String? icon;
  final bool selected;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : YgColors.moss;
    return YgPressable(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: YgMotion.tap,
        curve: YgMotion.tapCurve,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? YgColors.moss : Colors.white,
          borderRadius: BorderRadius.circular(height / 2),
          border: selected
              ? null
              : Border.all(color: YgColors.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              YgIcon(icon!, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: -.13,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Control segmentado con pulgar deslizante (`.seg`).
class YgSegmented extends StatelessWidget {
  const YgSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final reduce = YgMotionScope.reduced(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: YgColors.control,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: reduce
                    ? YgMotion.reduced
                    : const Duration(milliseconds: 450),
                curve: const Cubic(.34, 1.3, .5, 1),
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x242C3424),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(i),
                        child: Semantics(
                          button: true,
                          selected: i == index,
                          label: labels[i],
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              style: DefaultTextStyle.of(context).style.merge(
                                TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: i == index
                                      ? YgColors.text
                                      : YgColors.text3,
                                ),
                              ),
                              child: Text(labels[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Interruptor iOS de 51×31 (`.sw`).
class YgSwitch extends StatelessWidget {
  const YgSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final reduce = YgMotionScope.reduced(context);
    final d = reduce ? YgMotion.reduced : const Duration(milliseconds: 350);
    return Semantics(
      toggled: value,
      label: semanticLabel,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: d,
          curve: Curves.easeOut,
          width: 51,
          height: 31,
          decoration: BoxDecoration(
            color: value ? YgColors.cypress : YgColors.aloe,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedAlign(
            duration: d,
            curve: const Cubic(.34, 1.4, .5, 1),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 27,
              height: 27,
              margin: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x402C3424),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
