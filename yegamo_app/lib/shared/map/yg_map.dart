import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../design_system/yg_motion.dart';
import 'yg_map_model.dart';
import 'yg_map_painter.dart';
import 'yg_map_view.dart';

/// Capa de mapa: port de `MapLayer.dc.html`. Dibuja el mapa base de Guayaquil
/// (grabado una sola vez en un `Picture`), cámara con planeo y 3D, y — solo
/// con [showDemoOverlays] — rutas, paradas y vehículos de demostración.
class YgMap extends StatefulWidget {
  const YgMap({
    super.key,
    required this.view,
    required this.controller,
    this.showDemoOverlays = false,
  });

  final YgMapView view;
  final YgMapController controller;

  /// Solo en datos de demostración se dibujan rutas, buses y paradas
  /// simulados; nunca se presentan como datos reales.
  final bool showDemoOverlays;

  @override
  State<YgMap> createState() => _YgMapState();
}

class _Repaint extends ChangeNotifier {
  void poke() => notifyListeners();
}

class _YgMapState extends State<YgMap> with SingleTickerProviderStateMixin {
  final YgMapModel _model = YgMapModel();
  final _Repaint _repaint = _Repaint();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _rm = false;
  String? _family;
  YgMapPainter? _painter;

  // Gestos
  final Map<int, Offset> _pointers = {};
  Offset? _downAt;
  Offset _panAtDown = Offset.zero;
  bool _moved = false;
  double _pinchDist = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.controller.addListener(_onController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rm = YgMotionScope.reduced(context);
    final fam = DefaultTextStyle.of(context).style.fontFamily;
    if (_painter == null || fam != _family) {
      _family = fam;
      _painter = YgMapPainter(_model, fam, _repaint);
    }
    _apply();
  }

  @override
  void didUpdateWidget(covariant YgMap old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
    }
    _apply();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _onController() => _apply();

  double get _wall {
    final ts = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    return ts.inMicroseconds / 1e6;
  }

  void _apply() {
    final c = widget.controller;
    _model.apply(
      view: widget.view,
      demo: widget.showDemoOverlays,
      rm: _rm,
      zoom: c.zoom,
      pan: c.pan,
      dragging: c.dragging,
      wall: _wall,
    );
    _wake();
    _repaint.poke();
  }

  void _wake() {
    if (_model.needsTicks && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _model.step(dt < 0 ? 0 : dt);
    _repaint.poke();
    if (!_model.needsTicks) _ticker.stop();
  }

  // ---- gestos (umbral de arrastre 6 px como en el prototipo) ----

  double _k(BuildContext context) {
    final w = context.size?.width ?? 390;
    return w / 390;
  }

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      _downAt = e.localPosition;
      _panAtDown = widget.controller.pan;
      _moved = false;
    } else if (_pointers.length == 2) {
      _pinchDist = _spread();
      _moved = true;
    }
  }

  double _spread() {
    final p = _pointers.values.toList();
    return (p[0] - p[1]).distance;
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length >= 2) {
      final d = _spread();
      if (_pinchDist > 0 && d > 0) {
        widget.controller.zoomBy(d / _pinchDist);
      }
      _pinchDist = d;
      return;
    }
    final down = _downAt;
    if (down == null) return;
    final k = _k(context);
    final delta = (e.localPosition - down) / k;
    if (!_moved) {
      if (delta.dx.abs() + delta.dy.abs() < 6) return;
      _moved = true;
    }
    widget.controller.panTo(_panAtDown + delta, dragging: true);
  }

  void _up(PointerEvent e) {
    final wasOnly = _pointers.length == 1;
    _pointers.remove(e.pointer);
    final down = _downAt;
    if (!wasOnly || down == null) {
      if (_pointers.isEmpty) _downAt = null;
      return;
    }
    _downAt = null;
    final k = _k(context);
    if (_moved) {
      if (e is PointerUpEvent) {
        widget.controller.panTo(
          _panAtDown + (e.localPosition - down) / k,
          dragging: false,
        );
      } else {
        widget.controller.panTo(widget.controller.pan, dragging: false);
      }
      return;
    }
    if (e is PointerUpEvent) {
      final size = context.size;
      final cb = widget.view.onPickStop;
      if (size != null && cb != null) {
        final hit = _painter?.hitStop(e.localPosition, size);
        if (hit != null) cb(hit);
      }
    }
  }

  void _signal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      widget.controller.zoomBy(e.scrollDelta.dy < 0 ? 1.12 : 1 / 1.12);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mapa de Guayaquil',
      container: true,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        onPointerSignal: _signal,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _painter,
            isComplex: true,
            willChange: true,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
