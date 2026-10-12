import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../env/config/app_config.dart';
import 'yg_map.dart';
import 'yg_map_view.dart';

/// Mapa persistente bajo el `Navigator` (se monta en `MaterialApp.builder`).
/// Las pantallas con mapa son transparentes y declaran su [YgMapView] con
/// [YgMapBinding]; el mapa anima la cámara entre pantallas.
class YgMapHost extends StatelessWidget {
  const YgMapHost({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scope = context.read<YgMapScope>();
    final config = context.read<AppConfig>();
    return Stack(
      fit: StackFit.expand,
      children: [
        ListenableBuilder(
          listenable: scope,
          builder: (context, _) => YgMap(
            view: scope.view,
            controller: scope.controller,
            showDemoOverlays: config.demoDataEnabled,
          ),
        ),
        ?child,
      ],
    );
  }
}

/// Declara qué debe mostrar el mapa mientras esta pantalla está activa.
class YgMapBinding extends StatefulWidget {
  const YgMapBinding({
    super.key,
    required this.view,
    required this.child,
    this.active = true,
  });

  final YgMapView view;
  final Widget child;

  /// Para pestañas en un `IndexedStack`: solo la pestaña visible gobierna el
  /// mapa.
  final bool active;

  @override
  State<YgMapBinding> createState() => _YgMapBindingState();
}

class _YgMapBindingState extends State<YgMapBinding> {
  YgMapScope? _scope;

  void _push() {
    final scope = _scope;
    if (scope == null || !widget.active) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    scope.show(this, widget.view);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = context.read<YgMapScope>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _push();
    });
  }

  @override
  void didUpdateWidget(covariant YgMapBinding old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _push();
    });
  }

  @override
  void dispose() {
    _scope?.release(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
