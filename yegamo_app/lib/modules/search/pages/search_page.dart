import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/location/location_service.dart';
import '../../../shared/map/yg_map_host.dart';
import '../../../shared/map/yg_map_view.dart';
import '../../../shared/models/data_state.dart';
import '../../../shared/navigation/app_routes.dart';
import '../../nearby/widgets/freshness_label.dart';
import '../../saved/providers/saved_view_model.dart';
import '../providers/search_view_model.dart';
import '../widgets/no_coverage_view.dart';
import '../widgets/search_widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();
  final YgSheetController _sheet = YgSheetController(YgSnap.mid);
  double _sheetH = YgSheetConfig.search.mid;
  double _sheetB = YgSheetConfig.search.bottom;

  /// Consulta ejecutada con éxito o fallo; `null` mientras no se haya buscado.
  String? _searched;
  bool _hasLocation = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final vm = context.read<SearchViewModel>();
      final location = context.read<LocationService>();
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.trim().isNotEmpty) {
        _useQuery(args);
      } else {
        vm.loadRecents();
      }
      final access = await location.checkPermission();
      if (mounted) {
        setState(() => _hasLocation = access == LocationAccess.granted);
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _sheet.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final vm = context.read<SearchViewModel>();
    final text = _controller.text.trim();
    vm.setQuery(_controller.text);
    if (text.isEmpty) {
      setState(() => _searched = null);
      return;
    }
    setState(() => _searched = text);
    FocusScope.of(context).unfocus();
    _sheet.setSnap(YgSnap.mid);
    await vm.search();
  }

  void _useQuery(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    _search();
  }

  void _clear() {
    _controller.clear();
    setState(() => _searched = null);
    final vm = context.read<SearchViewModel>();
    vm.setQuery('');
    vm.loadRecents();
  }

  YgMapDataState _mapState(UxState s) => switch (s) {
    UxState.stale => YgMapDataState.stale,
    UxState.degraded => YgMapDataState.degraded,
    UxState.offline => YgMapDataState.offline,
    UxState.error => YgMapDataState.error,
    UxState.permission => YgMapDataState.permission,
    _ => YgMapDataState.ok,
  };

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    final snapshot = vm.snapshot;
    final state = snapshot.state;

    if (state == UxState.noCoverage) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: NoCoverageView(
          destination: _searched ?? vm.query,
          onBack: _clear,
          onChangeDestination: _clear,
        ),
      );
    }

    final saved = context.select<SavedViewModel, List<String>>(
      (s) => s.state.items.map((p) => p.label).toList(growable: false),
    );
    final visibleBottom =
        MediaQuery.sizeOf(context).height - _sheetB - _sheetH - 16;
    final showEmpty = state == UxState.empty && _searched != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: YgMapBinding(
        view: YgMapView(
          mode: YgMapMode.search,
          ds: _mapState(state),
          locOn: _hasLocation,
          visibleBottom: visibleBottom.toDouble(),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            YgEnter(
              kind: YgEnterKind.fade,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  YgSheet(
                    key: const ValueKey('search_sheet'),
                    config: YgSheetConfig.search,
                    controller: _sheet,
                    onHeightChanged: (h, b) {
                      if (h == _sheetH && b == _sheetB) return;
                      setState(() {
                        _sheetH = h;
                        _sheetB = b;
                      });
                    },
                    header: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('¿A dónde vas?', style: YgText.title2),
                            Tooltip(
                              message: 'Cerrar',
                              child: YgIconButton(
                                key: const ValueKey('search_close'),
                                icon: YgIcons.cerrar,
                                style: YgIconButtonStyle.secondary,
                                size: YgSize.iconButtonSm,
                                semanticLabel: 'Cerrar',
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    body: (context, snap) => SingleChildScrollView(
                      physics: snap == YgSnap.max || _searched != null
                          ? const ClampingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SearchOriginDestination(
                            controller: _controller,
                            focusNode: _focus,
                            originText: _hasLocation
                                ? 'Mi ubicación'
                                : 'Elige un origen',
                            loading: vm.loading,
                            onSubmit: _search,
                          ),
                          if (saved.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SearchQuickChips(labels: saved, onPick: _useQuery),
                          ],
                          const SizedBox(height: 16),
                          YgGroup(
                            children: [
                              YgListRow(
                                key: const ValueKey('search_manual_origin'),
                                icon: YgIcons.mapa,
                                title: 'Usar origen manual',
                                subtitle: 'Elige tú el punto de partida',
                                showChevron: true,
                                onTap: () =>
                                    Navigator.of(context)
                                        .pushNamed(AppRoutes.planner),
                              ),
                            ],
                          ),
                          ..._results(vm, state, showEmpty),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _results(SearchViewModel vm, UxState state, bool showEmpty) {
    final snapshot = vm.snapshot;
    final recents = snapshot.recentQueries;
    if (state == UxState.loading) {
      return const [
        SizedBox(height: 32),
        Center(child: YgSpinner(size: 24, width: 2.5)),
        SizedBox(height: 12),
        Center(child: Text('Buscando…', style: YgText.secondary)),
      ];
    }
    if (showEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 24, 4, 0),
          child: YgOverline('Resultados'),
        ),
        SearchEmptyState(query: _searched!, onClear: _clear),
      ];
    }
    if (state == UxState.ok && snapshot.results.isNotEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 24, 4, 12),
          child: YgOverline('Resultados'),
        ),
        YgEnter(
          child: YgGroup(
            children: [
              for (final result in snapshot.results)
                YgListRow(
                  key: ValueKey('result_${result.id}'),
                  icon: YgIcons.ubicacion,
                  title: result.name,
                  subtitle: result.source == 'openstreetmap-nominatim'
                      ? 'OpenStreetMap · lugar geocodificado'
                      : result.dataState == DataState.degraded
                      ? 'Datos limitados'
                      : 'Lugar encontrado',
                  trailing: result.dataState == DataState.current
                      ? null
                      : YgFreshnessLabel(result.dataState),
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(AppRoutes.planner, arguments: result),
                ),
            ],
          ),
        ),
      ];
    }
    final widgets = <Widget>[];
    final problem = searchProblemFor(state);
    if (problem != null) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(
          YgBanner(
            title: problem.title,
            message: problem.message,
            icon: problem.icon,
            tone: problem.tone,
            actionLabel: _searched != null && problem.retry
                ? 'Reintentar'
                : null,
            onAction: vm.loading ? null : _search,
          ),
        );
    }
    if (recents.isNotEmpty) {
      widgets
        ..add(
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 24, 4, 12),
            child: YgOverline('Recientes'),
          ),
        )
        ..add(
          YgEnter(
            child: YgGroup(
              children: [
                for (final recent in recents)
                  YgListRow(
                    key: ValueKey('recent_$recent'),
                    icon: YgIcons.reloj,
                    title: recent,
                    onTap: () => _useQuery(recent),
                  ),
              ],
            ),
          ),
        );
    }
    return widgets;
  }
}
