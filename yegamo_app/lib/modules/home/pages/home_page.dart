import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/location/location_service.dart';
import '../../../shared/map/yg_map_controls.dart';
import '../../../shared/map/yg_map_host.dart';
import '../../../shared/map/yg_map_view.dart';
import '../../../shared/models/data_state.dart';
import '../../../shared/navigation/app_navigator.dart';
import '../../../shared/navigation/app_routes.dart';
import '../../journey/providers/journey_view_model.dart';
import '../../nearby/providers/nearby_view_model.dart';
import '../../notifications/providers/notifications_view_model.dart';
import '../../saved/providers/saved_view_model.dart';
import '../../search/widgets/search_widgets.dart';
import '../providers/home_view_model.dart';
import '../widgets/home_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.active = true});

  /// `false` cuando otra pestaña está visible en el `IndexedStack`.
  final bool active;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final YgSheetController _sheet = YgSheetController(YgSnap.mid);
  double _sheetH = YgSheetConfig.home.mid;
  double _sheetB = YgSheetConfig.home.bottom;
  LocationAccess? _access;

  @override
  void initState() {
    super.initState();
    _sheet.addListener(_onSnap);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _sheet.removeListener(_onSnap);
    _sheet.dispose();
    super.dispose();
  }

  void _onSnap() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final home = context.read<HomeViewModel>();
    final saved = context.read<SavedViewModel>();
    final nearby = context.read<NearbyViewModel>();
    final location = context.read<LocationService>();
    home.load();
    // Retoma un viaje en curso (local o de cuenta) tras cerrar o reiniciar la app.
    context.read<JourneyViewModel>().restore();
    if (saved.state.items.isEmpty && !saved.loading) saved.load();
    final access = await location.checkPermission();
    if (!mounted) return;
    setState(() => _access = access);
    // Solo se consultan paradas cercanas si el sistema ya concedió ubicación.
    if (access == LocationAccess.granted &&
        nearby.snapshot.stops.isEmpty &&
        !nearby.loading) {
      nearby.load();
    }
  }

  YgMapDataState _mapState(UxState s) => switch (s) {
    UxState.stale => YgMapDataState.stale,
    UxState.degraded => YgMapDataState.degraded,
    UxState.offline => YgMapDataState.offline,
    UxState.error => YgMapDataState.error,
    UxState.empty => YgMapDataState.empty,
    UxState.permission => YgMapDataState.permission,
    _ => YgMapDataState.ok,
  };

  void _push(String route, {Object? arguments}) =>
      Navigator.of(context).pushNamed(route, arguments: arguments);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final state = vm.loading ? UxState.loading : vm.snapshot.state;
    final unread = context.select<NotificationsViewModel, int>(
      (n) => n.state.unreadCount,
    );
    final savedLabels = context.select<SavedViewModel, List<String>>(
      (s) => s.state.items.map((p) => p.label).toList(growable: false),
    );
    final nearby = context.watch<NearbyViewModel>().snapshot;
    final journeyState = context.watch<JourneyViewModel>().state.journey;
    final activeJourney = journeyState != null && !journeyState.isTerminal
        ? journeyState
        : null;

    final located =
        _access != null &&
        _access == LocationAccess.granted &&
        state != UxState.permission;
    final noLocation =
        (_access != null && !located) || state == UxState.permission;
    final copy = HomeDepartureCopy.forState(state, located: !noLocation);
    final retryable =
        state == UxState.offline ||
        state == UxState.stale ||
        state == UxState.degraded ||
        state == UxState.error;
    final visibleBottom = 844 - _sheetB - _sheetH - 16;

    return YgMapScaffold(
      body: YgMapBinding(
        active: widget.active,
        view: YgMapView(
          mode: YgMapMode.home,
          ds: _mapState(state),
          locOn: !noLocation,
          visibleBottom: visibleBottom.toDouble(),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            HomeHeader(
              locationLabel: noLocation ? 'Sin ubicación' : 'Estás en',
              locationName: noLocation ? 'Elige un origen' : 'Mi ubicación',
              unread: unread,
              onLocation: () => _push(AppRoutes.search),
              onNotices: () => context.read<AppShellController>().selectTab(3),
              onSettings: () => _push(AppRoutes.settings),
            ),
            if (activeJourney != null && state != UxState.offline)
              Positioned(
                top: YgSize.floatY,
                left: 16,
                right: 16,
                child: YgBanner(
                  floating: true,
                  title: 'Viaje en curso',
                  message: activeJourney.dataState == DataState.offlineCache
                      ? 'Sin conexión: mostrando tu último estado guardado'
                      : 'Paso ${(activeJourney.currentLegIndex + 1).clamp(1, activeJourney.totalLegs == 0 ? 1 : activeJourney.totalLegs)} de ${activeJourney.totalLegs}',
                  icon: YgIcons.navegar,
                  actionLabel: 'Continuar',
                  onAction: () => _push(AppRoutes.activeJourney),
                ),
              ),
            if (state == UxState.offline)
              Positioned(
                top: YgSize.floatY,
                left: 16,
                right: 16,
                child: YgBanner(
                  floating: true,
                  title: 'Sin conexión',
                  message: 'Sin datos en vivo',
                  icon: YgIcons.sinConexion,
                  actionLabel: 'Reintentar',
                  onAction: vm.loading ? null : vm.load,
                ),
              ),
            YgMapControls(
              sheetHeight: _sheetH,
              sheetBottom: _sheetB,
              hidden: _sheet.snap == YgSnap.max,
            ),
            YgSheet(
              config: YgSheetConfig.home,
              controller: _sheet,
              onHeightChanged: (h, b) {
                if (h == _sheetH && b == _sheetB) return;
                setState(() {
                  _sheetH = h;
                  _sheetB = b;
                });
              },
              peek: HomePeek(
                copy: copy,
                onPlan: () => _push(AppRoutes.planner),
              ),
              body: (context, snap) => SingleChildScrollView(
                physics: snap == YgSnap.max
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _pad(
                      YgEnter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (noLocation)
                              HomePermissionCard(
                                onChooseOrigin: () => _push(AppRoutes.search),
                                onEnable: () => _push(AppRoutes.permissions),
                              ),
                            YgEnter(
                              kind: YgEnterKind.hero,
                              child: HomeHero(
                                copy: copy,
                                onPlan: () => _push(AppRoutes.planner),
                                onRetry: retryable && !vm.loading
                                    ? vm.load
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _pad(
                      YgEnter(
                        delay: const Duration(milliseconds: 50),
                        child: HomeSearchField(
                          onTap: () => _push(AppRoutes.search),
                        ),
                      ),
                    ),
                    if (savedLabels.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _pad(
                        YgEnter(
                          delay: const Duration(milliseconds: 100),
                          child: SearchQuickChips(
                            labels: savedLabels,
                            keyPrefix: 'home_quick_',
                            onPick: (label) =>
                                _push(AppRoutes.search, arguments: label),
                          ),
                        ),
                      ),
                    ],
                    _pad(
                      YgEnter(
                        delay: const Duration(milliseconds: 150),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 24, bottom: 12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 32),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Cerca de ti', style: YgText.title),
                                KeyedSubtree(
                                  key: const ValueKey('home_nearby'),
                                  child: YgLink(
                                    'Ver todo',
                                    onTap: () => _push(AppRoutes.nearby),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (nearby.state == UxState.ok && nearby.stops.isNotEmpty)
                      YgEnter(
                        delay: const Duration(milliseconds: 200),
                        child: SizedBox(
                          height: 108,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            clipBehavior: Clip.none,
                            itemCount: nearby.stops.length.clamp(0, 6),
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) => HomeNearCard(
                              key: ValueKey('home_stop_${nearby.stops[i].id}'),
                              stop: nearby.stops[i],
                              onTap: () => _push(AppRoutes.nearby),
                            ),
                          ),
                        ),
                      )
                    else
                      _pad(
                        YgEnter(
                          delay: const Duration(milliseconds: 200),
                          child: Text(
                            _nearbyHint(nearby.state, noLocation),
                            style: YgText.secondary,
                          ),
                        ),
                      ),
                    _pad(
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(
                          state == UxState.offline
                              ? 'Sin conexión · no hay datos en vivo'
                              : 'Los datos de transporte aparecen solo con una '
                                    'fuente autorizada y frescura explícita.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            color: YgColors.text3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pad(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: child,
  );

  static String _nearbyHint(UxState state, bool noLocation) {
    if (noLocation) {
      return 'Activa la ubicación o elige un origen para ver paradas cerca.';
    }
    return switch (state) {
      UxState.loading => 'Buscando paradas cercanas…',
      UxState.offline => 'Sin conexión. No podemos mostrar paradas ahora.',
      UxState.degraded ||
      UxState.error => 'No hay una fuente de paradas disponible por ahora.',
      _ => 'Abre «Ver todo» para consultar las paradas más cercanas.',
    };
  }
}
