import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'yg_icon.dart';
import 'yg_motion.dart';
import 'yg_tokens.dart';

/// Fondo «Bosque claro»: blanco dominante con velo oliva de 13–17 %
/// (`--yg-bg` del prototipo).
class YgBackground extends StatelessWidget {
  const YgBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: const _BgPainter(), child: child);
  }
}

class _BgPainter extends CustomPainter {
  const _BgPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFF4F6F0)],
          stops: [0, .42, 1],
        ).createShader(rect),
    );
    _glow(canvas, size, Offset(size.width, 0), size.width * 1.2,
        size.height * .55, const Color(0xFF959581), .13, .58);
    _glow(canvas, size, Offset(0, size.height), size.width * 1.3,
        size.height * .6, const Color(0xFF768064), .17, .62);
  }

  void _glow(Canvas canvas, Size size, Offset c, double rx, double ry,
      Color color, double a, double stop) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(c.dx, c.dy);
    canvas.scale(rx, ry);
    canvas.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          1,
          [color.withValues(alpha: a), color.withValues(alpha: 0)],
          [0, stop],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Superficie translúcida con desenfoque (`.glass`): barras, controles del
/// mapa y píldoras flotantes.
class YgGlass extends StatelessWidget {
  const YgGlass({
    super.key,
    required this.child,
    this.radius = 22,
    this.opacity = .9,
    this.blur = 20,
    this.padding,
    this.shadow = YgShadows.glass,
    this.width,
    this.height,
  });

  final Widget child;
  final double radius;
  final double opacity;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow> shadow;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: shadow),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur / 2, sigmaY: blur / 2),
          child: Container(
            width: width,
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: r,
              border: Border.all(
                color: YgColors.moss.withValues(alpha: .1),
                width: .5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta del sistema v3: radio 20, relleno 16, borde `#E6E8E1`, sombra suave.
class YgCard extends StatelessWidget {
  const YgCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(YgSpace.card),
    this.radius = YgRadius.card,
    this.selected = false,
    this.color = YgColors.surface,
    this.shadow = true,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool selected;
  final Color color;
  final bool shadow;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final deco = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: YgMotion.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: selected ? YgColors.moss : YgColors.border,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: shadow
            ? (selected
                  ? const [
                      BoxShadow(
                        color: Color(0x1F2C3424),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ]
                  : YgShadows.card)
            : null,
      ),
      child: child,
    );
    if (onTap == null) return deco;
    return YgPressable(onTap: onTap, semanticLabel: semanticLabel, child: deco);
  }
}

enum YgTileTone { normal, cypress, aloe, clay, moss }

/// Tile de icono 36 con radio 10 (`.tile`).
class YgTile extends StatelessWidget {
  const YgTile({
    super.key,
    required this.icon,
    this.tone = YgTileTone.normal,
    this.size = YgSize.tile,
    this.iconSize = 18,
    this.radius = YgRadius.tile,
  });

  final String icon;
  final YgTileTone tone;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      YgTileTone.normal => (YgColors.fill, YgColors.cypress),
      YgTileTone.cypress => (YgColors.cypress, Colors.white),
      YgTileTone.aloe => (YgColors.aloe, YgColors.moss),
      YgTileTone.clay => (const Color(0x1F9C4F3A), YgColors.clay),
      YgTileTone.moss => (YgColors.moss, Colors.white),
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: YgIcon(icon, size: iconSize, color: fg),
    );
  }
}

/// Grupo de filas (`.grp`): tarjeta que recorta y separa filas.
class YgGroup extends StatelessWidget {
  const YgGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: YgColors.surface,
        borderRadius: BorderRadius.circular(YgRadius.card),
        border: Border.all(color: YgColors.border),
        boxShadow: YgShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const YgRowDivider(),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Separador alineado al texto (inicio a 64 px).
class YgRowDivider extends StatelessWidget {
  const YgRowDivider({super.key, this.indent = 64});

  final double indent;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: EdgeInsets.only(left: indent),
    color: YgColors.divider,
  );
}

/// Fila de lista (`.li`): alto mínimo 56, tile + contenido + valor/acción.
class YgListRow extends StatelessWidget {
  const YgListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.tone = YgTileTone.normal,
    this.leading,
    this.value,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.titleStyle,
    this.minHeight = YgSize.listRow,
  });

  final String title;
  final String? subtitle;
  final String? icon;
  final YgTileTone tone;
  final Widget? leading;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final TextStyle? titleStyle;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)]
            else if (icon != null) ...[
              YgTile(icon: icon!, tone: tone),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        titleStyle ??
                        YgText.body.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: YgText.secondary),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 12),
              Text(
                value!,
                style: YgText.body.copyWith(color: YgColors.text3),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            if (showChevron) ...[
              const SizedBox(width: 8),
              const YgIcon(
                YgIcons.chevronDerecha,
                size: 16,
                color: YgColors.muted,
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return YgPressable(onTap: onTap, semanticLabel: title, child: row);
  }
}

/// Etiqueta de sección (`.ovl`) en mayúsculas.
class YgOverline extends StatelessWidget {
  const YgOverline(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: YgText.overline.copyWith(color: color ?? YgColors.text3),
  );
}

/// Cabecera de sección (`.sec-h`): título + acción opcional.
class YgSectionHeader extends StatelessWidget {
  const YgSectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.only(top: 24, bottom: 12),
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: YgText.title),
            if (action != null) YgLink(action!, onTap: onAction),
          ],
        ),
      ),
    );
  }
}

/// Enlace de texto (`.lnk`).
class YgLink extends StatelessWidget {
  const YgLink(this.label, {super.key, this.onTap, this.bold = false});

  final String label;
  final VoidCallback? onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return YgPressable(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1,
            child: Text(
              label,
              style: YgText.body.copyWith(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: YgColors.cypress,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
