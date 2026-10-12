import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/widgets/yg_page.dart';
import '../models/commute_models.dart';
import '../providers/commutes_view_model.dart';
import '../widgets/routine_widgets.dart';

class CommutesPage extends StatefulWidget {
  const CommutesPage({super.key});

  @override
  State<CommutesPage> createState() => _CommutesPageState();
}

class _CommutesPageState extends State<CommutesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CommutesViewModel>().load();
    });
  }

  Future<void> _edit({CommuteRoutine? routine}) async {
    final result = await showRoutineEditor(context, routine: routine);
    if (result == null || !mounted) return;
    final vm = context.read<CommutesViewModel>();
    if (result.delete && routine != null) {
      await vm.remove(routine.id);
      if (!mounted) return;
      YgToast.show(context, vm.state.message ?? 'Rutina eliminada');
    } else if (result.routine != null) {
      await vm.save(result.routine!);
      if (!mounted) return;
      YgToast.show(context, vm.state.message ?? 'Rutina guardada');
    }
  }

  Future<void> _toggle(CommuteRoutine routine) async {
    final vm = context.read<CommutesViewModel>();
    final pausing = !routine.isPaused;
    await vm.toggle(routine);
    if (!mounted) return;
    YgToast.show(
      context,
      vm.state.message ?? (pausing ? 'Rutina en pausa' : 'Rutina activada'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CommutesViewModel>();
    final items = vm.state.items;
    return YgPage(
      children: [
        YgNavRow(
          title: 'Rutinas',
          trailing: YgIconButton(
            icon: YgIcons.mas,
            style: YgIconButtonStyle.secondary,
            semanticLabel: 'Nueva rutina',
            onPressed: vm.loading ? null : _edit,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Te avisamos cuándo salir cada día y recalculamos antes de notificarte.',
            style: YgText.secondary,
          ),
        ),
        const YgGroupHeader('Mis rutinas'),
        if (items.isEmpty)
          YgEnter(
            child: YgBanner(
              title: 'Aún no tienes rutinas',
              message:
                  'Crea una para recordar tus trayectos frecuentes. Los avisos respetan la zona horaria del dispositivo.',
              icon: YgIcons.transbordo,
              tone: YgBannerTone.plain,
              actionLabel: 'Crear rutina',
              onAction: vm.loading ? null : _edit,
            ),
          )
        else
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: ygRise(
                index: i,
                RoutineCard(
                  routine: items[i],
                  onToggle: vm.loading ? null : (_) => _toggle(items[i]),
                  onEdit: () => _edit(routine: items[i]),
                ),
              ),
            ),
      ],
    );
  }
}
