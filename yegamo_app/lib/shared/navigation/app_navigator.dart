import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../modules/home/pages/home_page.dart';
import '../../modules/saved/pages/saved_page.dart';
import '../../modules/commutes/pages/commutes_page.dart';
import '../../modules/notifications/pages/notifications_page.dart';
import '../../modules/notifications/providers/notifications_view_model.dart';
import '../../modules/onboarding/task_five_app.dart';
import '../design_system/yg_components.dart';
import '../map/yg_map_host.dart';
import 'app_routes.dart';

class AppShellController extends ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void selectTab(int index) {
    if (index < 0 || index >= _rootTabs.length || index == _selectedIndex) {
      return;
    }
    _selectedIndex = index;
    notifyListeners();
  }

  static const _rootTabs = <String>[
    AppRoutes.home,
    AppRoutes.saved,
    AppRoutes.commutes,
    AppRoutes.notifications,
  ];
}

class AppNavigator extends StatelessWidget {
  const AppNavigator({super.key});

  static const _rootTabs = <String>[
    AppRoutes.home,
    AppRoutes.saved,
    AppRoutes.commutes,
    AppRoutes.notifications,
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppShellController>();
    final unread = context.select<NotificationsViewModel, int>(
      (vm) => vm.state.unreadCount,
    );
    final index = controller.selectedIndex;
    return YgMapScaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(
            index: index,
            children: [
              for (var i = 0; i < _rootTabs.length; i++)
                _RootTabPage(
                  definition: AppRoutes.definitionFor(_rootTabs[i]),
                  active: i == index,
                ),
            ],
          ),
          Positioned(
            left: YgSpace.gutter,
            right: YgSpace.gutter,
            bottom: YgSize.tabbarBottom,
            child: YgEnter(
              kind: YgEnterKind.up,
              child: YgTabBar(
                index: index,
                onChanged: controller.selectTab,
                items: [
                  const YgTabItem(YgIcons.mapa, 'Inicio'),
                  const YgTabItem(YgIcons.guardado, 'Guardados'),
                  const YgTabItem(YgIcons.transbordo, 'Rutinas'),
                  YgTabItem(YgIcons.campana, 'Avisos', badge: unread),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegisteredScreenPage extends StatelessWidget {
  const RegisteredScreenPage({super.key, required this.definition});

  final AppRouteDefinition definition;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(definition.title),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                tooltip: 'Volver',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: YgCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(definition.icon, size: 40),
                const SizedBox(height: 12),
                Text(
                  definition.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Superficie registrada en la fundación compartida. '
                  'La capacidad se conectará en su vertical correspondiente.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RootTabPage extends StatelessWidget {
  const _RootTabPage({required this.definition, required this.active});

  final AppRouteDefinition definition;

  /// Solo la pestaña visible gobierna el mapa persistente.
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (definition.name == AppRoutes.home) {
      return HomePage(active: active);
    }
    if (definition.name == AppRoutes.saved) return const SavedPage();
    if (definition.name == AppRoutes.commutes) return const CommutesPage();
    if (definition.name == AppRoutes.notifications) {
      return const NotificationsPage();
    }
    return TaskFivePlaceholderPage(definition: definition);
  }
}
