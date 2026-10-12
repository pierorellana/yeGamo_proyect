import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'yg_controls.dart';
import 'yg_icon.dart';
import 'yg_motion.dart';
import 'yg_surfaces.dart';
import 'yg_tokens.dart';

enum YgSnap { min, mid, max }

/// Alturas de los tres estados del panel inferior (mínimo, intermedio,
/// expandido) y su desplazamiento desde el borde (96 sobre la barra de
/// pestañas, 8 en el resto).
class YgSheetConfig {
  const YgSheetConfig(this.min, this.mid, this.max, {this.bottom = 8});

  final double min;
  final double mid;
  final double max;
  final double bottom;

  double heightFor(YgSnap s) => switch (s) {
    YgSnap.min => min,
    YgSnap.mid => mid,
    YgSnap.max => max,
  };

  // Valores del prototipo (`sheetCfg`).
  static const home = YgSheetConfig(124, 356, 640, bottom: 96);
  static const search = YgSheetConfig(132, 548, 760);
  static const nearby = YgSheetConfig(116, 404, 726);
  static const planner = YgSheetConfig(132, 548, 726);
  static const alternatives = YgSheetConfig(124, 448, 726);
  static const departure = YgSheetConfig(124, 472, 726);
  static const steps = YgSheetConfig(132, 448, 726);
  static const active = YgSheetConfig(148, 332, 620);
}

class YgSheetController extends ChangeNotifier {
  YgSheetController([this._snap = YgSnap.mid]);

  YgSnap _snap;
  YgSnap get snap => _snap;

  void setSnap(YgSnap s) {
    if (s == _snap) return;
    _snap = s;
    notifyListeners();
  }

  void cycle() => setSnap(switch (_snap) {
    YgSnap.min => YgSnap.mid,
    YgSnap.mid => YgSnap.max,
    YgSnap.max => YgSnap.mid,
  });
}

/// Panel inferior arrastrable con tres alturas y resorte de 0,55 s.
///
/// [header] se pinta bajo el asa y es la zona de arrastre; [peek] se muestra
/// solo en estado mínimo; [body] solo en intermedio/expandido. El desplazamiento
/// interno solo está activo en estado expandido.
class YgSheet extends StatefulWidget {
  const YgSheet({
    super.key,
    required this.config,
    required this.body,
    this.header,
    this.peek,
    this.controller,
    this.initial = YgSnap.mid,
    this.onHeightChanged,
    this.scrollController,
    this.handleLabel = 'Cambiar altura del panel',
  });

  final YgSheetConfig config;
  final Widget Function(BuildContext context, YgSnap snap) body;
  final Widget? header;
  final Widget? peek;
  final YgSheetController? controller;
  final YgSnap initial;

  /// Altura actual (px) y desplazamiento inferior; usado por el mapa para
  /// ajustar su cámara y la columna de controles.
  final void Function(double height, double bottom)? onHeightChanged;
  final ScrollController? scrollController;
  final String handleLabel;

  @override
  State<YgSheet> createState() => _YgSheetState();
}

class _YgSheetState extends State<YgSheet> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final AnimationController _h = AnimationController.unbounded(vsync: this);
  late YgSheetController _ctl;
  bool _ownsCtl = false;
  DateTime _justDragged = DateTime.fromMillisecondsSinceEpoch(0);
  bool _started = false;

  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 240,
    damping: 21,
  );

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _ctl = widget.controller!;
    } else {
      _ctl = YgSheetController(widget.initial);
      _ownsCtl = true;
    }
    _ctl.addListener(_onSnap);
    _h.value = widget.config.heightFor(_ctl.snap);
    _h.addListener(_report);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (YgMotionScope.reduced(context)) {
      _enter.value = 1;
    } else {
      _enter.animateTo(1, curve: const Cubic(.22, 1.06, .36, 1));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void didUpdateWidget(covariant YgSheet old) {
    super.didUpdateWidget(old);
    if (old.config != widget.config) _settle();
  }

  @override
  void dispose() {
    _ctl.removeListener(_onSnap);
    if (_ownsCtl) _ctl.dispose();
    _enter.dispose();
    _h.dispose();
    super.dispose();
  }

  void _report() =>
      widget.onHeightChanged?.call(_h.value, widget.config.bottom);

  void _onSnap() {
    _settle();
    setState(() {});
  }

  void _settle([double velocity = 0]) {
    final to = widget.config.heightFor(_ctl.snap);
    if (YgMotionScope.reduced(context)) {
      _h.value = to;
      return;
    }
    _h.animateWith(SpringSimulation(_spring, _h.value, to, velocity));
  }

  void _dragUpdate(DragUpdateDetails d) {
    final c = widget.config;
    var h = _h.value - d.delta.dy;
    
    _h
      ..stop()
      ..value = h.clamp(c.min - 40, c.max + 24);
  }

  void _dragEnd(DragEndDetails d) {
    _justDragged = DateTime.now();
    final c = widget.config;
    final v = d.velocity.pixelsPerSecond.dy; // + hacia abajo
    final proj = _h.value - v * .24;
    var best = YgSnap.mid;
    var bd = double.infinity;
    for (final s in YgSnap.values) {
      final x = (c.heightFor(s) - proj).abs();
      if (x < bd) {
        bd = x;
        best = s;
      }
    }
    if (best == _ctl.snap) {
      _settle(-v);
    } else {
      _ctl.setSnap(best);
    }
  }

  void _tap() {
    if (DateTime.now().difference(_justDragged).inMilliseconds < 400) return;
    _ctl.cycle();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final snap = _ctl.snap;
    return Positioned(
      left: 8,
      right: 8,
      bottom: c.bottom,
      child: AnimatedBuilder(
        animation: Listenable.merge([_h, _enter]),
        builder: (context, _) {
          final h = _h.value.clamp(0.0, 4000.0);
          return FractionalTranslation(
            translation: Offset(0, 1.05 * (1 - _enter.value)),
            child: _SheetSurface(
              height: h,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: _dragUpdate,
                    onVerticalDragEnd: _dragEnd,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          button: true,
                          label: widget.handleLabel,
                          onTap: _tap,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _tap,
                            child: const SizedBox(
                              height: 24,
                              width: double.infinity,
                              child: Center(child: _Grabber()),
                            ),
                          ),
                        ),
                        if (widget.header != null) widget.header!,
                        if (snap == YgSnap.min && widget.peek != null)
                          YgEnter(kind: YgEnterKind.fade, child: widget.peek!),
                      ],
                    ),
                  ),
                  if (snap != YgSnap.min || widget.peek == null)
                    Expanded(
                      child: ClipRect(
                        child: YgEnter(
                          key: ValueKey(snap == YgSnap.min),
                          kind: YgEnterKind.fade,
                          child: widget.body(context, snap),
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 5,
    decoration: BoxDecoration(
      color: YgColors.handle,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(YgRadius.sheet);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: YgShadows.sheet),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: r,
              border: Border.all(
                color: YgColors.moss.withValues(alpha: .08),
                width: .5,
              ),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xF7FFFFFF),
                  Color(0xF7FFFFFF),
                  Color(0xF7F6F8F2),
                ],
                stops: [0, .55, 1],
              ),
            ),
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}

/// Hoja modal (`.msheet`): fondo blanco, radio 32, escrim 28 %, pie fijo.
Future<T?> showYgModalSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  final reduce = YgMotionScope.reduced(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Cerrar',
    barrierColor: const Color(0x471E2419),
    transitionDuration: reduce
        ? YgMotion.reduced
        : const Duration(milliseconds: 600),
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(YgRadius.sheet),
          elevation: 0,
          shadowColor: Colors.transparent,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  height: 20,
                  child: Center(child: _Grabber()),
                ),
                Flexible(child: builder(context)),
              ],
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, anim, _, child) {
      if (reduce) return FadeTransition(opacity: anim, child: child);
      final curved = CurvedAnimation(
        parent: anim,
        curve: const Cubic(.22, 1.08, .36, 1),
        reverseCurve: Curves.easeIn,
      );
      return SlideTransition(
        position: Tween(
          begin: const Offset(0, 1.05),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

/// Cabecera de hoja modal (`.mhead`): acción izquierda, título, acción derecha.
class YgModalHeader extends StatelessWidget {
  const YgModalHeader({
    super.key,
    required this.title,
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: leftLabel == null
                ? null
                : Align(
                    alignment: Alignment.centerLeft,
                    child: YgPressable(
                      onTap: onLeft,
                      child: Text(
                        leftLabel!,
                        style: YgText.body.copyWith(
                          color: YgColors.text2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: YgText.title,
            ),
          ),
          SizedBox(
            width: 88,
            child: rightLabel == null
                ? null
                : Align(
                    alignment: Alignment.centerRight,
                    child: YgLink(rightLabel!, onTap: onRight, bold: true),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Destinos de la barra de pestañas principal.
class YgTabItem {
  const YgTabItem(this.icon, this.label, {this.badge = 0});

  final String icon;
  final String label;
  final int badge;
}

/// Barra de pestañas flotante (`.tabbar`): vidrio, indicador moss que se
/// desliza con resorte, insignia en Avisos.
class YgTabBar extends StatelessWidget {
  const YgTabBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<YgTabItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final reduce = YgMotionScope.reduced(context);
    return Semantics(
      container: true,
      label: 'Navegación principal',
      child: YgGlass(
        radius: 32,
        height: YgSize.tabbarHeight,
        padding: const EdgeInsets.all(4),
        opacity: .9,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth / items.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: reduce
                      ? YgMotion.reduced
                      : const Duration(milliseconds: 550),
                  curve: const Cubic(.34, 1.3, .5, 1),
                  left: w * index,
                  top: 0,
                  width: w,
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      color: YgColors.moss,
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(i),
                          child: Semantics(
                            button: true,
                            selected: i == index,
                            label: items[i].label,
                            excludeSemantics: true,
                            child: _TabCell(
                              item: items[i],
                              selected: i == index,
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
      ),
    );
  }
}

class _TabCell extends StatelessWidget {
  const _TabCell({required this.item, required this.selected});

  final YgTabItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : YgColors.text2;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            YgIcon(item.icon, size: 20, color: color),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 350),
              style: DefaultTextStyle.of(context).style.merge(
                TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              child: Text(item.label),
            ),
          ],
        ),
        if (item.badge > 0)
          Positioned(top: 4, right: 18, child: YgBadge(item.badge)),
      ],
    );
  }
}

/// Barra superior flotante (`.topbar`): botón atrás + píldora de título.
class YgTopBar extends StatelessWidget {
  const YgTopBar({
    super.key,
    this.onBack,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.backLabel = 'Volver',
    this.backIcon = YgIcons.atras,
  });

  final VoidCallback? onBack;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final String backLabel;
  final String backIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: YgSize.topbarY),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (onBack != null)
              YgIconButton(
                icon: backIcon,
                onPressed: onBack,
                semanticLabel: backLabel,
              ),
            if (onBack != null) const SizedBox(width: 8),
            if (title != null)
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 236),
                  child: YgGlass(
                    radius: 22,
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: YgText.sub.copyWith(fontSize: 14, height: 1.2),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: YgText.meta.copyWith(height: 1.2),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (leading != null) leading!,
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
