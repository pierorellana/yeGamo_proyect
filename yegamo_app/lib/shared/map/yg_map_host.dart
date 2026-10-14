import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../env/config/app_config.dart';
import '../../modules/nearby/providers/nearby_view_model.dart';
import '../../modules/search/providers/search_view_model.dart';
import '../location/location_service.dart';
import '../models/data_state.dart';
import 'yg_map.dart';
import 'yg_real_map.dart';
import 'yg_map_view.dart';

/// Superficie transparente para pantallas que viven sobre el mapa persistente.
///
/// Un [Scaffold] normal crea un [Material] tipo canvas que participa en el
/// hit-test de toda la pantalla, incluso con fondo transparente. Eso impide
/// que el mapa que está debajo reciba arrastres y pellizcos en las zonas sin
/// controles. Este material transparente conserva los descendientes
/// interactivos y deja pasar los gestos por el resto de la superficie.
class YgMapScaffold extends StatelessWidget {
  const YgMapScaffold({super.key, required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) =>
      Material(type: MaterialType.transparency, child: body);
}

/// Captura los gestos en la zona libre del mapa persistente.
///
/// El mapa nativo vive bajo el Navigator, y el Navigator participa en el
/// hit-test aunque su ruta sea visualmente transparente. Por eso esta capa
/// envuelve al Navigator y comparte sus eventos con él. Solo acepta gestos
/// cuyo inicio esté sobre el área libre del mapa; los paneles, botones y
/// campos siguen usando sus propios recognizers.
class YgMapGestureSurface extends StatefulWidget {
  const YgMapGestureSurface({
    super.key,
    required this.controller,
    required this.mapBottom,
    required this.child,
  });

  final YgMapController controller;
  final double mapBottom;
  final Widget child;

  @override
  State<YgMapGestureSurface> createState() => _YgMapGestureSurfaceState();
}

class _YgMapGestureSurfaceState extends State<YgMapGestureSurface> {
  static const _pinchZoomSensitivity = 20.0;

  double _lastScale = 1;

  void _onScaleStart(ScaleStartDetails _) => _lastScale = 1;

  void _onScaleUpdate(ScaleUpdateDetails details) {
    widget.controller.panBy(details.focalPointDelta);
    final scale = details.scale;
    if (!scale.isFinite || scale <= 0) return;
    final factor = scale / _lastScale;
    if ((factor - 1).abs() >= .001) {
      final adjustedFactor = math.pow(factor, _pinchZoomSensitivity).toDouble();
      widget.controller.zoomBy(adjustedFactor);
      _lastScale = scale;
    }
  }

  void _onScaleEnd(ScaleEndDetails _) => _lastScale = 1;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        _YgMapScaleGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_YgMapScaleGestureRecognizer>(
              () => _YgMapScaleGestureRecognizer(mapBottom: widget.mapBottom),
              (recognizer) {
                recognizer
                  ..mapBottom = widget.mapBottom
                  ..onStart = _onScaleStart
                  ..onUpdate = _onScaleUpdate
                  ..onEnd = _onScaleEnd;
              },
            ),
      },
      child: widget.child,
    );
  }
}

class _YgMapScaleGestureRecognizer extends ScaleGestureRecognizer {
  _YgMapScaleGestureRecognizer({required this.mapBottom});

  double mapBottom;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (event.localPosition.dy >= mapBottom) return;
    super.addAllowedPointer(event);
  }
}

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
    final nearby = context.watch<NearbyViewModel>().snapshot;
    final search = context.watch<SearchViewModel>().snapshot;
    final points = <YgMapPoint>[
      for (final stop in nearby.stops)
        if (stop.latitude != null && stop.longitude != null)
          YgMapPoint(
            id: stop.id,
            latitude: stop.latitude!,
            longitude: stop.longitude!,
            kind: YgMapPointKind.stop,
            dataState: stop.dataState.apiValue,
          ),
      for (final place in search.results)
        YgMapPoint(
          id: place.id,
          latitude: place.latitude,
          longitude: place.longitude,
          kind: YgMapPointKind.place,
          dataState: place.dataState.apiValue,
        ),
    ];
    return Stack(
      fit: StackFit.expand,
      children: [
        ListenableBuilder(
          listenable: scope,
          builder: (context, _) => config.realMapEnabled
              ? YgRealMap(
                  view: scope.view,
                  config: config,
                  locationService: context.read<LocationService>(),
                  mapController: scope.controller,
                  points: points,
                  focusTarget: scope.focusTarget,
                  focusRequestVersion: scope.focusRequestVersion,
                )
              : YgMap(
                  view: scope.view,
                  controller: scope.controller,
                  showDemoOverlays: config.demoDataEnabled,
                ),
        ),
        if (config.realMapEnabled)
          ListenableBuilder(
            listenable: scope,
            builder: (context, _) => YgMapGestureSurface(
              controller: scope.controller,
              mapBottom: scope.view.visibleBottom,
              child: child ?? const SizedBox.expand(),
            ),
          )
        else
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
