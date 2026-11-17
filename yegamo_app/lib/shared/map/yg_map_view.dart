import 'dart:async';

import 'package:flutter/foundation.dart';

import '../location/location_service.dart';
import 'yg_real_map.dart';
import 'package:flutter/widgets.dart';

/// Modo de la capa de mapa (equivale a `view.mode` de MapLayer del prototipo).
enum YgMapMode {
  showcase,
  home,
  perm,
  search,
  nearby,
  planner,
  loading,
  alts,
  depart,
  steps,
  active,
  getoff,
  arrived,
  nocov,
}

/// Fase del viaje activo (`view.phase`).
enum YgTripPhase { walk, wait, ride, walk2, done }

/// Estado de datos que modula vehículos en vivo/estimados (`view.ds`).
enum YgMapDataState { ok, stale, degraded, offline, error, empty, permission }

/// Descripción declarativa de lo que debe mostrar el mapa (`view` del
/// prototipo). Los widgets de pantalla construyen un [YgMapView] y el host lo
/// anima suavemente hacia el nuevo encuadre.
@immutable
class YgMapView {
  const YgMapView({
    this.mode = YgMapMode.home,
    this.alt = 0,
    this.phase = YgTripPhase.ride,
    this.u = 0,
    this.w = 0,
    this.sp = 0,
    this.ds = YgMapDataState.ok,
    this.sel = 0,
    this.locOn = true,
    this.fit = false,
    this.visibleBottom = 760,
    this.tags = const <String>[],
    this.subs = const <String>[],
    this.onPickStop,
  });

  final YgMapMode mode;

  /// Alternativa seleccionada (0–2).
  final int alt;
  final YgTripPhase phase;

  /// Progreso 0–1 de la caminata (`u`) y de la espera/aproximación del bus (`w`).
  final double u;
  final double w;

  /// Posición del bus a lo largo del tramo en transporte (0–6, índice de
  /// segmento con fracción).
  final double sp;
  final YgMapDataState ds;

  /// Parada seleccionada en modo `nearby`.
  final int sel;
  final bool locOn;

  /// «Ver recorrido completo».
  final bool fit;

  /// Y (px lógicos de 844) donde termina el área libre sobre el panel inferior.
  final double visibleBottom;
  final List<String> tags;
  final List<String> subs;
  final ValueChanged<int>? onPickStop;

  @override
  bool operator ==(Object other) =>
      other is YgMapView &&
      other.mode == mode &&
      other.alt == alt &&
      other.phase == phase &&
      other.u == u &&
      other.w == w &&
      other.sp == sp &&
      other.ds == ds &&
      other.sel == sel &&
      other.locOn == locOn &&
      other.fit == fit &&
      other.visibleBottom == visibleBottom &&
      listEquals(other.tags, tags) &&
      listEquals(other.subs, subs);

  @override
  int get hashCode => Object.hash(
    mode,
    alt,
    phase,
    u,
    w,
    sp,
    ds,
    sel,
    locOn,
    fit,
    visibleBottom,
    Object.hashAll(tags),
    Object.hashAll(subs),
  );
}

/// Controla la cámara del usuario sobre el mapa (zoom, recentrado).
class YgMapController extends ChangeNotifier {
  double _zoom = 1;
  Offset _pan = Offset.zero;
  bool _dragging = false;
  Future<void> Function(double)? _nativeZoomBy;
  Future<void> Function(Offset)? _nativePanBy;
  Future<void> Function()? _nativeReset;

  double get zoom => _zoom;
  Offset get pan => _pan;
  bool get dragging => _dragging;
  bool get userMoved => _pan != Offset.zero || _zoom != 1;

  void attachNativeCamera({
    required Future<void> Function(double) zoomBy,
    Future<void> Function(Offset)? panBy,
    required Future<void> Function() reset,
  }) {
    _nativeZoomBy = zoomBy;
    _nativePanBy = panBy;
    _nativeReset = reset;
  }

  void detachNativeCamera() {
    _nativeZoomBy = null;
    _nativePanBy = null;
    _nativeReset = null;
  }

  void zoomBy(double f) {
    _zoom = (_zoom * f).clamp(.5, 3.0);
    notifyListeners();
    final nativeZoomBy = _nativeZoomBy;
    if (nativeZoomBy != null && f.isFinite && f > 0) {
      unawaited(nativeZoomBy(f));
    }
  }

  void panBy(Offset delta) {
    if (delta == Offset.zero) return;
    _pan += delta;
    _dragging = true;
    notifyListeners();
    final nativePanBy = _nativePanBy;
    if (nativePanBy != null) unawaited(nativePanBy(delta));
  }

  void panTo(Offset pan, {bool dragging = false}) {
    _pan = pan;
    _dragging = dragging;
    notifyListeners();
  }

  /// Vuelve al encuadre propio del modo (botón «centrar en mi ubicación»).
  void reset() {
    _zoom = 1;
    _pan = Offset.zero;
    _dragging = false;
    notifyListeners();
    final nativeReset = _nativeReset;
    if (nativeReset != null) unawaited(nativeReset());
  }
}

/// Estado compartido entre las pantallas y el mapa persistente que vive bajo
/// el `Navigator`, de modo que la cámara se desliza entre pantallas como en el
/// prototipo.
class YgMapScope extends ChangeNotifier {
  YgMapScope();

  YgMapView _view = const YgMapView();
  final YgMapController controller = YgMapController();
  List<YgMapPoint> _routePoints = const [];
  List<YgMapLine> _routeLines = const [];
  ValueChanged<GeoCoordinate>? _tapHandler;
  Object? _tapOwner;
  Object? _owner;
  GeoCoordinate? _focusTarget;
  int _focusRequestVersion = 0;

  YgMapView get view => _view;
  GeoCoordinate? get focusTarget => _focusTarget;
  List<YgMapPoint> get routePoints => _routePoints;
  List<YgMapLine> get routeLines => _routeLines;
  ValueChanged<GeoCoordinate>? get tapHandler => _tapHandler;

  /// La pantalla activa publica el recorrido real que debe dibujarse.
  void showRoute(List<YgMapPoint> points, List<YgMapLine> lines) {
    if (_disposed) return;
    _routePoints = points;
    _routeLines = lines;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void clearRoute() {
    if (_disposed) return; // Llamado desde un microtask tras cerrar la app.
    if (_routePoints.isEmpty && _routeLines.isEmpty) return;
    _routePoints = const [];
    _routeLines = const [];
    notifyListeners();
  }

  /// Registra quién recibe los toques del mapa (selección de ubicación).
  void setTapHandler(Object owner, ValueChanged<GeoCoordinate>? handler) {
    _tapOwner = handler == null ? null : owner;
    _tapHandler = handler;
  }

  void releaseTapHandler(Object owner) {
    if (_tapOwner == owner) {
      _tapOwner = null;
      _tapHandler = null;
    }
  }
  int get focusRequestVersion => _focusRequestVersion;

  void focusOn(GeoCoordinate point) {
    _focusTarget = point;
    _focusRequestVersion += 1;
    notifyListeners();
  }

  /// Registra la vista del mapa. [owner] identifica a la pantalla activa; solo
  /// ella puede actualizarla hasta que otra tome el control.
  void show(Object owner, YgMapView view) {
    if (_owner == owner && _view == view) return;
    final changedMode = _view.mode != view.mode || _view.fit != view.fit;
    _owner = owner;
    _view = view;
    if (changedMode) controller.reset();
    notifyListeners();
  }

  void release(Object owner) {
    if (_owner == owner) _owner = null;
  }
}
