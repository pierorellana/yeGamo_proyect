import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/widgets/yg_float.dart';
import '../../../shared/widgets/yg_page.dart';
import '../providers/notifications_view_model.dart';
import '../widgets/notification_widgets.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsViewModel>().load();
    });
  }

  Future<void> _readAll() async {
    final vm = context.read<NotificationsViewModel>();
    await vm.markAllRead();
    if (!mounted) return;
    YgToast.show(context, vm.state.message ?? 'Avisos marcados como leídos');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>();
    final items = vm.state.items;
    final groups = groupByDay(items);
    return YgPage(
      children: [
        YgNavRow(
          title: 'Avisos',
          trailing: vm.state.unreadCount > 0
              ? YgLink('Marcar todo leído', onTap: _readAll)
              : null,
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 64),
            child: YgEnter(child: _EmptyNotices()),
          ),
        for (final group in groups) ...[
          YgGroupHeader(group.$1),
          YgEnter(
            child: YgGroup(
              children: [
                for (final item in group.$2)
                  NotificationRow(
                    item: item,
                    onTap: () => vm.markRead(item.id),
                  ),
              ],
            ),
          ),
        ],
        const Padding(
          padding: EdgeInsets.only(top: 24),
          child: Text(
            'Solo avisos útiles: salida, cambios de hora, bajada y afectaciones de ruta.',
            textAlign: TextAlign.center,
            style: YgText.meta,
          ),
        ),
      ],
    );
  }
}

class _EmptyNotices extends StatelessWidget {
  const _EmptyNotices();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Column(
        children: [
          YgFloat(
            child: SvgPicture.asset(
              'assets/ilustraciones/avisos-vacio.svg',
              width: 220,
              height: 120,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Todo tranquilo', style: YgText.title),
          const SizedBox(height: 8),
          const SizedBox(
            width: 280,
            child: Text(
              'Te avisaremos cuándo salir, si cambia tu hora o cuándo bajarte. Nada de ruido.',
              textAlign: TextAlign.center,
              style: YgText.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
