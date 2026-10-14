import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../env/config/app_config.dart';
import '../../../shared/design_system/yg_components.dart';
import '../../../shared/location/location_service.dart';
import '../../../shared/map/yg_map_controls.dart';
import '../../../shared/map/yg_map_host.dart';
import '../../../shared/map/yg_map_view.dart';
import '../../../shared/models/data_state.dart';
import '../../../shared/navigation/app_routes.dart';
import '../models/nearby_models.dart';
import '../providers/nearby_view_model.dart';
import '../widgets/freshness_label.dart';
import '../widgets/map_top_row.dart';
import '../widgets/nearby_widgets.dart';
import '../../search/widgets/no_coverage_view.dart';

class NearbyPage extends StatefulWidget {
  const NearbyPage({super.key});

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  late final TextEditingController _manualController;
  final YgSheetController _sheet = YgSheetController(YgSnap.mid);
  double _sheetH = YgSheetConfig.nearby.mid;
  double _sheetB = YgSheetConfig.nearby.bottom;
  int _sel = 0;

  @override
  void initState() {
    super.initState();
    _manualController = TextEditingController();
    _sheet.addListener(_onSnap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NearbyViewModel>().load();
    });
  }

  @override
  void dispose() {
    _sheet.removeListener(_onSnap);
    _sheet.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onSnap() {
    if (mounted) setState(() {});
  }

  Future<void> _loadManual() async {
    final parts = _manualController.text
        .split(',')
        .map((part) => double.tryParse(part.trim()))
        .toList();
    if (parts.length != 2 || parts.any((value) => value == null)) {
      YgToast.show(context, 'Usa el formato latitud, longitud.');
      return;
    }
    context.read<NearbyViewModel>().setManualOrigin(
      GeoCoordinate(latitude: parts[0]!, longitude: parts[1]!),
    );
    await context.read<NearbyViewModel>().load();
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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NearbyViewModel>();
    final snapshot = vm.snapshot;
    final state = vm.loading ? UxState.loading : snapshot.state;
    final radiusLabel = context.read<AppConfig>().demoDataEnabled
        ? '3 km'
        : '1 km';

    if (state == UxState.noCoverage) {
      return YgMapScaffold(
        body: NoCoverageView(
          onBack: () => Navigator.of(context).maybePop(),
          onChangeDestination: () =>
              Navigator.of(context).pushReplacementNamed(AppRoutes.search),
        ),
      );
    }

    final List<NearbyStop> stops = state == UxState.ok
        ? snapshot.stops
        : const <NearbyStop>[];
    final sel = stops.isEmpty ? 0 : _sel.clamp(0, stops.length - 1);
    final visibleBottom = 844 - _sheetB - _sheetH - 16;

    return YgMapScaffold(
      body: YgMapBinding(
        view: YgMapView(
          mode: YgMapMode.nearby,
          sel: sel,
          ds: _mapState(state),
          visibleBottom: visibleBottom.toDouble(),
          onPickStop: (i) => setState(() => _sel = i),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            YgMapTopRow(
              title: 'Cerca de ti',
              subtitle: stops.isEmpty
                  ? 'Radio de $radiusLabel'
                  : '${stops.length} ${stops.length == 1 ? 'parada' : 'paradas'} · radio de $radiusLabel',
              onBack: () => Navigator.of(context).maybePop(),
              trailingIcon: YgIcons.buscar,
              trailingLabel: 'Buscar',
              onTrailing: () =>
                  Navigator.of(context).pushNamed(AppRoutes.search),
            ),
            YgMapControls(
              sheetHeight: _sheetH,
              sheetBottom: _sheetB,
              hidden: _sheet.snap == YgSnap.max,
            ),
            YgSheet(
              config: YgSheetConfig.nearby,
              controller: _sheet,
              onHeightChanged: (h, b) {
                if (h == _sheetH && b == _sheetB) return;
                setState(() {
                  _sheetH = h;
                  _sheetB = b;
                });
              },
              header: AnimatedBuilder(
                animation: _sheet,
                builder: (context, _) => _sheet.snap == YgSnap.min
                    ? const SizedBox.shrink()
                    : _Header(
                        trailing: state == UxState.ok
                            ? '${stops.length} ${stops.length == 1 ? 'parada' : 'paradas'}'
                            : _stateTag(state),
                      ),
              ),
              peek: _Peek(
                state: state,
                stop: stops.isEmpty ? null : stops[sel],
              ),
              body: (context, snap) => _Body(
                snap: snap,
                state: state,
                stops: stops,
                selected: sel,
                onPick: (i) => setState(() => _sel = i),
                onRetry: vm.loading ? null : vm.load,
                manualController: _manualController,
                onManual: vm.loading ? null : _loadManual,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _stateTag(UxState s) => switch (s) {
    UxState.loading => 'consultando',
    UxState.offline => 'sin conexión',
    UxState.stale => 'desactualizado',
    UxState.degraded => 'datos limitados',
    UxState.permission => 'sin ubicación',
    UxState.error => 'sin respuesta',
    _ => '',
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.trailing});

  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Paradas cercanas', style: YgText.title),
          Text(trailing, style: YgText.meta.copyWith(color: YgColors.text3)),
        ],
      ),
    );
  }
}

class _Peek extends StatelessWidget {
  const _Peek({required this.state, required this.stop});

  final UxState state;
  final NearbyStop? stop;

  @override
  Widget build(BuildContext context) {
    final s = stop;
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          const YgTile(icon: YgIcons.bus, tone: YgTileTone.cypress),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s?.name ?? 'Paradas cercanas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: YgText.secondary.copyWith(
                    fontWeight: FontWeight.w600,
                    color: YgColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                if (s != null)
                  YgFreshnessLabel(s.dataState)
                else
                  Text(
                    state == UxState.loading
                        ? 'Consultando…'
                        : 'Sin paradas para mostrar',
                    style: YgText.meta,
                  ),
              ],
            ),
          ),
          if (s != null)
            Text(
              nearbyDistanceLabel(s),
              style: YgText.eta.copyWith(fontSize: 17),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.snap,
    required this.state,
    required this.stops,
    required this.selected,
    required this.onPick,
    required this.onRetry,
    required this.manualController,
    required this.onManual,
  });

  final YgSnap snap;
  final UxState state;
  final List<NearbyStop> stops;
  final int selected;
  final ValueChanged<int> onPick;
  final VoidCallback? onRetry;
  final TextEditingController manualController;
  final VoidCallback? onManual;

  @override
  Widget build(BuildContext context) {
    final stale = state == UxState.stale;
    final offline = state == UxState.offline;
    return SingleChildScrollView(
      physics: snap == YgSnap.max
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stale)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: YgBanner(
                title: 'Datos desactualizados',
                message: 'Pueden no reflejar dónde están los buses.',
                icon: YgIcons.reloj,
                actionLabel: 'Actualizar',
                onAction: onRetry,
              ),
            ),
          if (offline)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: YgBanner(
                title: 'Sin conexión',
                message: 'No mostramos posiciones ni horarios sin una fuente.',
                icon: YgIcons.sinConexion,
                tone: YgBannerTone.off,
              ),
            ),
          if (state == UxState.ok) ...[
            const NearbyLegend(),
            for (var i = 0; i < stops.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                child: YgEnter(
                  delay: ygStaggerDelay(i),
                  child: NearbyStopCard(
                    key: ValueKey('nearby_stop_${stops[i].id}'),
                    stop: stops[i],
                    selected: i == selected,
                    onTap: () => onPick(i),
                  ),
                ),
              ),
          ] else
            YgEnter(
              child: _StateCard(state: state, onRetry: onRetry),
            ),
          const SizedBox(height: 24),
          _ManualOrigin(controller: manualController, onSubmit: onManual),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Las distancias y salidas requieren ubicación y una fuente '
              'autorizada.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: YgColors.text3),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.state, required this.onRetry});

  final UxState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, tone, title, message, canRetry) = switch (state) {
      UxState.loading => (
        YgIcons.reloj,
        YgTileTone.normal,
        'Buscando paradas',
        'Estamos consultando paradas cerca de ti.',
        false,
      ),
      UxState.empty => (
        YgIcons.bus,
        YgTileTone.normal,
        'Sin paradas mapeadas cerca de ti',
        'No encontramos paradas de transporte en OpenStreetMap dentro del radio seleccionado.',
        false,
      ),
      UxState.permission => (
        YgIcons.ubicacionDesactivada,
        YgTileTone.clay,
        'Necesitamos tu ubicación',
        'Activa la ubicación o ingresa un origen manual para ver paradas.',
        false,
      ),
      UxState.offline => (
        YgIcons.sinConexion,
        YgTileTone.normal,
        'Sin conexión',
        'No hay red. Reintenta cuando vuelvas a conectarte.',
        true,
      ),
      UxState.degraded => (
        YgIcons.alerta,
        YgTileTone.aloe,
        'Datos limitados',
        'OpenStreetMap aporta ubicaciones de paradas; todavía no hay horarios ni posiciones en vivo.',
        true,
      ),
      _ => (
        YgIcons.alerta,
        YgTileTone.clay,
        'No pudimos cargar las paradas',
        'Inténtalo de nuevo en unos segundos.',
        true,
      ),
    };
    return YgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              YgTile(icon: icon, tone: tone),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: YgText.sub)),
              if (state == UxState.loading) const YgSpinner(),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: YgText.secondary),
          if (canRetry && onRetry != null) ...[
            const SizedBox(height: 12),
            YgButton(
              label: 'Reintentar',
              variant: YgButtonVariant.secondary,
              size: YgButtonSize.sm,
              onPressed: onRetry,
            ),
          ],
          if (state == UxState.permission) ...[
            const SizedBox(height: 12),
            YgButton(
              label: 'Permisos',
              variant: YgButtonVariant.secondary,
              size: YgButtonSize.sm,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.permissions),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManualOrigin extends StatelessWidget {
  const _ManualOrigin({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: YgOverline('Origen manual opcional'),
        ),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: YgColors.fill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const YgIcon(YgIcons.ubicacion, size: 18, color: YgColors.text3),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('nearby_manual_origin'),
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  style: YgText.body,
                  cursorColor: YgColors.cypress,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: 'latitud, longitud',
                    hintStyle: TextStyle(fontSize: 15, color: YgColors.text3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            YgButton(
              key: const ValueKey('nearby_refresh'),
              label: 'Actualizar',
              size: YgButtonSize.sm,
              onPressed: onSubmit,
            ),
            const SizedBox(width: 8),
            YgButton(
              label: 'Permisos',
              size: YgButtonSize.sm,
              variant: YgButtonVariant.secondary,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.permissions),
            ),
          ],
        ),
      ],
    );
  }
}
