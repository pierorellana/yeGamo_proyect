import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../env/config/app_config.dart';
import '../design_system/yg_tokens.dart';
import '../location/location_service.dart';
import 'yg_map_style.dart';
import 'yg_map_view.dart';

class YgMapPoint {
  const YgMapPoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.kind,
    required this.dataState,
  });

  final String id;
  final double latitude;
  final double longitude;
  final YgMapPointKind kind;
  final String dataState;
}

enum YgMapPointKind { stop, place, origin, destination }

/// Segmento dibujable. Solo se crea a partir de coordenadas que entrega el plan
/// (extremos de un tramo a pie); nunca se interpola una ruta de transporte.
class YgMapLine {
  const YgMapLine({required this.id, required this.coordinates, this.dashed = true});

  final String id;
  final List<GeoCoordinate> coordinates;
  final bool dashed;
}

class YgRealMap extends StatefulWidget {
  const YgRealMap({
    super.key,
    required this.view,
    required this.config,
    required this.locationService,
    required this.mapController,
    this.points = const <YgMapPoint>[],
    this.lines = const <YgMapLine>[],
    this.onTap,
    this.focusTarget,
    this.focusRequestVersion = 0,
  });

  final YgMapView view;
  final AppConfig config;
  final LocationService locationService;
  final YgMapController mapController;
  final List<YgMapPoint> points;
  final List<YgMapLine> lines;

  /// Toque sobre el mapa con coordenadas válidas (selección de ubicación).
  final ValueChanged<GeoCoordinate>? onTap;
  final GeoCoordinate? focusTarget;
  final int focusRequestVersion;

  @override
  State<YgRealMap> createState() => _YgRealMapState();
}

class _YgRealMapState extends State<YgRealMap> {
  static const _fallbackCenter = GeoCoordinate(
    latitude: -2.1700,
    longitude: -79.9000,
  );

  MapLibreMapController? _controller;
  Timer? _styleFallbackTimer;
  GeoCoordinate _center = _fallbackCenter;
  bool _locationGranted = false;
  bool _styleLoaded = false;
  bool _dynamicLayersAdded = false;
  bool _mapUnavailable = false;
  bool _usingFallbackStyle = false;
  int _lastFocusRequestVersion = 0;

  bool get _hasRemoteStyle => widget.config.mapStyleUrl.trim().isNotEmpty;

  bool get _usesFallbackStyle => !_hasRemoteStyle || _usingFallbackStyle;

  String get _styleString => _usesFallbackStyle
      ? YgMapStyle.fallback(tileUrl: widget.config.mapTileUrl)
      : widget.config.mapStyleUrl;

  @override
  void initState() {
    super.initState();
    _attachNativeCamera();
    _loadLocation();
    _scheduleStyleFallback();
  }

  @override
  void didUpdateWidget(covariant YgRealMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapController != widget.mapController) {
      oldWidget.mapController.detachNativeCamera();
      _attachNativeCamera();
    }
    if (!oldWidget.view.locOn && widget.view.locOn) _loadLocation();
    if (oldWidget.points != widget.points) _updateSources();
    if (oldWidget.focusRequestVersion != widget.focusRequestVersion) {
      _focusMap();
    }
  }

  void _attachNativeCamera() {
    widget.mapController.attachNativeCamera(
      zoomBy: _zoomBy,
      panBy: _panBy,
      reset: _resetCamera,
    );
  }

  Future<void> _zoomBy(double factor) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.zoomBy(log(factor) / log(2)));
  }

  Future<void> _panBy(Offset delta) async {
    final controller = _controller;
    if (controller == null) return;
    // CameraUpdate.scrollBy moves the camera target. To make the map follow
    // the user's finger, the camera moves in the opposite screen direction.
    await controller.moveCamera(CameraUpdate.scrollBy(-delta.dx, -delta.dy));
  }

  Future<void> _resetCamera() async {
    final controller = _controller;
    if (controller == null) return;
    final position = widget.view.locOn
        ? await widget.locationService.currentPosition()
        : null;
    final target = position ?? _center;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(target.latitude, target.longitude),
        position == null ? 12.5 : 13,
      ),
    );
  }

  void _scheduleStyleFallback() {
    if (!_hasRemoteStyle) return;
    _styleFallbackTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || _styleLoaded || _usingFallbackStyle) return;
      setState(() {
        _usingFallbackStyle = true;
        _styleLoaded = false;
        _dynamicLayersAdded = false;
        _mapUnavailable = false;
      });
    });
  }

  Future<void> _loadLocation() async {
    if (!widget.view.locOn) return;
    final position = await widget.locationService.currentPosition();
    if (!mounted || position == null) return;
    _locationGranted = true;
    _center = position;
    final controller = _controller;
    if (controller != null) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          13,
        ),
      );
    } else {
      setState(() {});
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    _focusMap();
  }

  Future<void> _focusMap() async {
    final target = widget.focusTarget;
    final controller = _controller;
    if (target == null ||
        controller == null ||
        widget.focusRequestVersion <= _lastFocusRequestVersion) {
      return;
    }
    _lastFocusRequestVersion = widget.focusRequestVersion;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(target.latitude, target.longitude), 15),
    );
  }

  Future<void> _onStyleLoaded() async {
    _styleFallbackTimer?.cancel();
    _styleLoaded = true;
    final controller = _controller;
    if (controller == null) return;
    try {
      if (!_usesFallbackStyle && !_dynamicLayersAdded) {
        await controller.addGeoJsonSource(
          'yegamo-stops',
          _featureCollection(YgMapPointKind.stop),
        );
        await controller.addGeoJsonSource(
          'yegamo-places',
          _featureCollection(YgMapPointKind.place),
        );
        await controller.addCircleLayer(
          'yegamo-stops',
          'yegamo-stops-layer',
          const CircleLayerProperties(
            circleRadius: 7,
            circleColor: '#4C583E',
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2,
          ),
        );
        await controller.addCircleLayer(
          'yegamo-places',
          'yegamo-places-layer',
          const CircleLayerProperties(
            circleRadius: 8,
            circleColor: '#9C4F3A',
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2,
          ),
        );
        await controller.addGeoJsonSource('yegamo-routes', _lineCollection());
        await controller.addLineLayer(
          'yegamo-routes',
          'yegamo-routes-layer',
          const LineLayerProperties(
            lineColor: '#4C583E',
            lineWidth: 4,
            lineDasharray: <double>[2, 2],
            lineCap: 'round',
          ),
        );
        await controller.addGeoJsonSource(
          'yegamo-endpoints',
          _featureCollection(YgMapPointKind.origin, YgMapPointKind.destination),
        );
        await controller.addCircleLayer(
          'yegamo-endpoints',
          'yegamo-endpoints-layer',
          const CircleLayerProperties(
            circleRadius: 9,
            circleColor: <dynamic>[
              'match',
              <dynamic>['get', 'kind'],
              'origin',
              '#2F7D4F',
              '#9C4F3A',
            ],
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 3,
          ),
        );
        _dynamicLayersAdded = true;
      }
      await _updateSources();
    } on Exception {
      if (mounted) setState(() => _mapUnavailable = true);
    }
  }

  Future<void> _updateSources() async {
    if (!_styleLoaded) return;
    final controller = _controller;
    if (controller == null) return;
    if (!_usesFallbackStyle && !_dynamicLayersAdded) return;
    try {
      await controller.setGeoJsonSource(
        'yegamo-stops',
        _featureCollection(YgMapPointKind.stop),
      );
      await controller.setGeoJsonSource(
        'yegamo-places',
        _featureCollection(YgMapPointKind.place),
      );
      await controller.setGeoJsonSource('yegamo-routes', _lineCollection());
      await controller.setGeoJsonSource(
        'yegamo-endpoints',
        _featureCollection(YgMapPointKind.origin, YgMapPointKind.destination),
      );
      await _fitRoute(controller);
    } on Exception {
      if (mounted) setState(() => _mapUnavailable = true);
    }
  }

  Map<String, dynamic> _lineCollection() => <String, dynamic>{
    'type': 'FeatureCollection',
    'features': widget.lines
        .where((line) => line.coordinates.length >= 2)
        .map(
          (line) => <String, dynamic>{
            'type': 'Feature',
            'id': line.id,
            'geometry': <String, dynamic>{
              'type': 'LineString',
              'coordinates': [
                for (final c in line.coordinates) <double>[c.longitude, c.latitude],
              ],
            },
            'properties': <String, dynamic>{'dashed': line.dashed},
          },
        )
        .toList(growable: false),
  };

  String _lastFitKey = '';

  /// Encuadra el recorrido (extremos y segmentos) cuando cambia.
  Future<void> _fitRoute(MapLibreMapController controller) async {
    final coords = <GeoCoordinate>[
      for (final p in widget.points)
        if (p.kind == YgMapPointKind.origin || p.kind == YgMapPointKind.destination)
          GeoCoordinate(latitude: p.latitude, longitude: p.longitude),
      for (final l in widget.lines) ...l.coordinates,
    ];
    final key = coords.map((c) => '${c.latitude},${c.longitude}').join('|');
    if (coords.length < 2 || key == _lastFitKey) return;
    _lastFitKey = key;
    var south = coords.first.latitude, north = south;
    var west = coords.first.longitude, east = west;
    for (final c in coords) {
      south = min(south, c.latitude);
      north = max(north, c.latitude);
      west = min(west, c.longitude);
      east = max(east, c.longitude);
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east)),
        left: 48,
        right: 48,
        top: 120,
        bottom: 320,
      ),
    );
  }

  Map<String, dynamic> _featureCollection(
    YgMapPointKind kind, [
    YgMapPointKind? alsoKind,
  ]) {
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': widget.points
          .where((point) => point.kind == kind || point.kind == alsoKind)
          .map(
            (point) => <String, dynamic>{
              'type': 'Feature',
              'id': point.id,
              'geometry': <String, dynamic>{
                'type': 'Point',
                'coordinates': <double>[point.longitude, point.latitude],
              },
              'properties': <String, dynamic>{
                'kind': point.kind.name,
                'dataState': point.dataState,
              },
            },
          )
          .toList(growable: false),
    };
  }

  @override
  void dispose() {
    _styleFallbackTimer?.cancel();
    widget.mapController.detachNativeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mapa real de yeGamo',
      container: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MapLibreMap(
            styleString: _styleString,
            initialCameraPosition: CameraPosition(
              target: LatLng(_center.latitude, _center.longitude),
              zoom: 12.5,
            ),
            onMapCreated: _onMapCreated,
            onMapClick: (_, latLng) {
              final lat = latLng.latitude;
              final lon = latLng.longitude;
              // Solo coordenadas válidas llegan a la pantalla que seleccionó el punto.
              if (lat.isFinite && lon.isFinite && lat.abs() <= 90 && lon.abs() <= 180) {
                widget.onTap?.call(GeoCoordinate(latitude: lat, longitude: lon));
              }
            },
            onStyleLoadedCallback: _onStyleLoaded,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
            },
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            tiltGesturesEnabled: true,
            doubleClickZoomEnabled: true,
            dragEnabled: true,
            myLocationEnabled: _locationGranted && widget.view.locOn,
            logoEnabled: false,
            compassEnabled: false,
            attributionButtonPosition: AttributionButtonPosition.bottomLeft,
            attributionButtonMargins: const Point<num>(16, 44),
            foregroundLoadColor: Colors.transparent,
          ),
          if (_usesFallbackStyle)
            const Positioned(
              left: 12,
              bottom: 8,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xCCF4F5F1),
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 10, color: YgColors.text2),
                    ),
                  ),
                ),
              ),
            ),
          if (_mapUnavailable)
            const Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xEEF4F5F1),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'El mapa no está disponible en este momento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: YgColors.text2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
