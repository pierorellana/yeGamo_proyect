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
                  points: points,
                )
              : YgMap(
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
