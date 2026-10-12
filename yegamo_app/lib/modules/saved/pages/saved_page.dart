import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/navigation/app_navigator.dart';
import '../../../shared/navigation/app_routes.dart';
import '../../../shared/session/session_service.dart';
import '../../../shared/widgets/yg_page.dart';
import '../models/saved_models.dart';
import '../providers/saved_view_model.dart';
import '../../../shared/widgets/yg_float.dart';
import '../widgets/saved_widgets.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SavedViewModel>().load();
    });
  }

  Future<void> _addPlace({String? presetLabel}) async {
    final labelController = TextEditingController(text: presetLabel);
    final subtitleController = TextEditingController();
    var confirmed = false;
    await showYgModalSheet<void>(
      context,
      builder: (sheetContext) => YgSheetBody(
        title: 'Guardar lugar',
        leftLabel: 'Volver',
        onLeft: () => Navigator.of(sheetContext).pop(),
        rightLabel: 'Guardar',
        onRight: () {
          confirmed = true;
          Navigator.of(sheetContext).pop();
        },
        children: [
          YgTextInput(
            controller: labelController,
            label: 'Nombre',
            autofocus: presetLabel == null,
          ),
          const SizedBox(height: 8),
          YgTextInput(
            controller: subtitleController,
            label: 'Descripción opcional',
          ),
        ],
      ),
    );
    final label = labelController.text.trim();
    final subtitle = subtitleController.text.trim();
    labelController.dispose();
    subtitleController.dispose();
    if (!confirmed || label.isEmpty || !mounted) return;
    final vm = context.read<SavedViewModel>();
    await vm.add(
      SavedPlace(
        id: 'local-${label.toLowerCase().replaceAll(RegExp(r'\s+'), '-')}',
        label: label,
        subtitle: subtitle.isEmpty ? null : subtitle,
      ),
    );
    if (!mounted) return;
    YgToast.show(context, vm.state.message ?? 'Lugar guardado');
  }

  Future<void> _remove(SavedPlace place) async {
    final vm = context.read<SavedViewModel>();
    await vm.remove(place.id);
    if (!mounted) return;
    YgToast.show(context, vm.state.message ?? 'Lugar eliminado');
  }

  void _goToRoutines() {
    Provider.of<AppShellController>(context, listen: false).selectTab(2);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SavedViewModel>();
    final session = context.watch<SessionManager>();
    final items = vm.state.items;
    final pinned = [
      for (final p in items)
        if (SavedKind.of(p).pinned) p,
    ];
    final others = [for (final p in items) if (!SavedKind.of(p).pinned) p];

    return YgPage(
      children: [
        YgNavRow(
          title: 'Guardados',
          trailing: YgIconButton(
            icon: YgIcons.mas,
            style: YgIconButtonStyle.secondary,
            semanticLabel: 'Añadir lugar',
            onPressed: vm.loading ? null : _addPlace,
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: YgEnter(
              child: _EmptySaved(
                onAdd: vm.loading
                    ? null
                    : () => _addPlace(presetLabel: 'Casa'),
              ),
            ),
          )
        else ...[
          if (pinned.isNotEmpty)
            YgEnter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _PinnedGrid(
                  places: pinned,
                  onRemove: vm.loading ? null : _remove,
                ),
              ),
            ),
          const YgGroupHeader('Otros lugares'),
          ygRise(
            index: 1,
            YgGroup(
              children: [
                for (final place in others)
                  SavedPlaceRow(
                    place: place,
                    onRemove: vm.loading ? null : () => _remove(place),
                  ),
                YgListRow(
                  icon: YgIcons.mas,
                  title: 'Añadir lugar',
                  titleStyle: YgText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: YgColors.cypress,
                  ),
                  onTap: vm.loading ? null : _addPlace,
                ),
              ],
            ),
          ),
        ],
        const YgGroupHeader('Más'),
        ygRise(
          index: 2,
          YgGroup(
            children: [
              YgListRow(
                icon: YgIcons.transbordo,
                title: 'Rutinas',
                subtitle: 'Avisos de salida programados',
                showChevron: true,
                onTap: _goToRoutines,
              ),
              YgListRow(
                icon: YgIcons.telefono,
                title: session.isGuest
                    ? 'Guardado en este dispositivo'
                    : 'Cuenta conectada',
                subtitle: session.isGuest
                    ? 'Crea una cuenta para sincronizar'
                    : 'Tus lugares se sincronizan',
                showChevron: true,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.settings),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinnedGrid extends StatelessWidget {
  const _PinnedGrid({required this.places, required this.onRemove});

  final List<SavedPlace> places;
  final ValueChanged<SavedPlace>? onRemove;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < places.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SavedPinnedCard(
                  place: places[i],
                  onRemove: onRemove == null ? null : () => onRemove!(places[i]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: i + 1 < places.length
                    ? SavedPinnedCard(
                        place: places[i + 1],
                        onRemove: onRemove == null
                            ? null
                            : () => onRemove!(places[i + 1]),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
      if (i + 2 < places.length) rows.add(const SizedBox(height: 8));
    }
    return Column(children: rows);
  }
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Column(
        children: [
          YgFloat(
            child: SvgPicture.asset(
              'assets/ilustraciones/guardados-vacio.svg',
              width: 200,
              height: 110,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aún no tienes lugares',
            style: YgText.title.copyWith(letterSpacing: -.34),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 280,
            child: Text(
              'Guarda Casa y Trabajo para planificar en un toque. Se quedan en este dispositivo.',
              textAlign: TextAlign.center,
              style: YgText.secondary,
            ),
          ),
          const SizedBox(height: 8),
          YgButton(
            label: 'Añadir Casa',
            size: YgButtonSize.sm,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
