import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../env/config/app_config.dart';
import '../../env/theme/yegamo_theme.dart';
import '../../shared/design_system/yg_components.dart';
import '../../shared/map/yg_map_host.dart';
import '../../shared/map/yg_map_view.dart';
import '../../shared/location/location_service.dart';
import '../../shared/navigation/app_navigator.dart';
import '../../shared/navigation/app_routes.dart';
import '../../shared/services/api_client.dart';
import '../../shared/session/token_store.dart';
import '../notifications/services/alerts_repository.dart';
import '../../shared/services/connectivity_service.dart';
import '../../shared/storage/local_storage.dart';
import '../../shared/session/session_service.dart';
import '../home/pages/home_page.dart';
import '../home/providers/home_view_model.dart';
import '../home/services/home_repository.dart';
import '../nearby/pages/nearby_page.dart';
import '../nearby/providers/nearby_view_model.dart';
import '../nearby/services/nearby_repository.dart';
import '../permissions/pages/permissions_page.dart';
import '../permissions/providers/permission_view_model.dart';
import '../permissions/services/permission_repository.dart';
import '../planner/pages/planner_pages.dart';
import '../planner/providers/planner_view_model.dart';
import '../planner/services/journey_repository.dart';
import '../search/pages/search_page.dart';
import '../search/providers/search_view_model.dart';
import '../search/services/search_repository.dart';
import '../journey/pages/journey_pages.dart';
import '../journey/providers/journey_view_model.dart';
import '../journey/services/active_journey_repository.dart';
import '../saved/pages/saved_page.dart';
import '../saved/providers/saved_view_model.dart';
import '../saved/services/saved_places_repository.dart';
import '../commutes/pages/commutes_page.dart';
import '../commutes/providers/commutes_view_model.dart';
import '../commutes/services/commutes_repository.dart';
import '../notifications/pages/notifications_page.dart';
import '../notifications/providers/notifications_view_model.dart';
import '../notifications/services/notifications_repository.dart';
import '../settings/pages/settings_page.dart';
import '../settings/providers/settings_view_model.dart';
import '../settings/services/settings_repository.dart';
import 'pages/entry_pages.dart';
import 'providers/onboarding_view_model.dart';
import 'services/onboarding_repository.dart';

/// The shared dependency scope for the entry/discovery/planning vertical.
/// Both the production app and the isolated vertical harness use this scope.
class TaskFiveScope extends StatelessWidget {
  const TaskFiveScope({
    super.key,
    required this.child,
    this.config = const AppConfig(),
    this.apiClient,
    this.localStorage,
    this.connectivityService,
    this.locationService,
  });

  final Widget child;
  final AppConfig config;
  final ApiClient? apiClient;
  final LocalStorage? localStorage;
  final ConnectivityService? connectivityService;
  final LocationService? locationService;

  @override
  Widget build(BuildContext context) {
    final storage = localStorage ?? InMemoryLocalStorage();
    final tokenStore = TokenStore(
      storage,
      refresher: config.oidcConfigured
          ? OidcTokenRefresher(
              tokenEndpoint: Uri.parse(config.oidcTokenEndpoint),
              clientId: config.oidcClientId,
            )
          : null,
    );
    final client =
        apiClient ??
        ApiClient(config: config, tokenProvider: tokenStore.validAccessToken);
    final connectivity = connectivityService ?? DeviceConnectivityService();
    final location = locationService ?? const GeolocatorLocationService();
    final consentStore = LocationConsentStore(storage);
    final locationReader = PrivacyAwareLocationReader(location, consentStore);

    return MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: config),
        Provider<ApiClient>.value(value: client),
        Provider<LocalStorage>.value(value: storage),
        Provider<TokenStore>.value(value: tokenStore),
        Provider<ConnectivityService>.value(value: connectivity),
        Provider<LocationService>.value(value: location),
        Provider<LocationConsentStore>.value(value: consentStore),
        ChangeNotifierProvider<SessionManager>(
          create: (_) => SessionManager(storage, tokens: tokenStore)..initialize(),
        ),
        ProxyProvider<SessionManager, AlertsRepository>(
          update: (context, session, _) =>
              AlertsRepository(storage, client, session),
        ),
        ChangeNotifierProvider<AppShellController>(
          create: (_) => AppShellController(),
        ),
        ChangeNotifierProvider<YgMapScope>(create: (_) => YgMapScope()),
        ChangeNotifierProvider(
          create: (context) => OnboardingViewModel(
            repository: OnboardingRepository(
              storage: context.read<LocalStorage>(),
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => PermissionViewModel(
            repository: PermissionRepository(
              locationService: context.read<LocationService>(),
              storage: context.read<LocalStorage>(),
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => HomeViewModel(
            repository: HomeRepository(
              apiClient: context.read<ApiClient>(),
              connectivity: context.read<ConnectivityService>(),
              storage: context.read<LocalStorage>(),
              locationService: context.read<LocationService>(),
              session: context.read<SessionManager>(),
              config: config,
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => SearchViewModel(
            repository: SearchRepository(
              apiClient: context.read<ApiClient>(),
              connectivity: context.read<ConnectivityService>(),
              storage: context.read<LocalStorage>(),
              locationService: context.read<LocationService>(),
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => NearbyViewModel(
            repository: NearbyRepository(
              apiClient: context.read<ApiClient>(),
              connectivity: context.read<ConnectivityService>(),
              locationService: context.read<LocationService>(),
              config: config,
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => PlannerViewModel(
            repository: JourneyRepository(apiClient: context.read<ApiClient>()),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => JourneyViewModel(
            ActiveJourneyRepository(
              context.read<ApiClient>(),
              context.read<LocalStorage>(),
              context.read<ConnectivityService>(),
              locationReader,
              context.read<SessionManager>(),
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => SavedViewModel(
            SavedPlacesRepository(
              context.read<LocalStorage>(),
              context.read<ApiClient>(),
              context.read<SessionManager>(),
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => CommutesViewModel(
            CommutesRepository(
              context.read<LocalStorage>(),
              context.read<ApiClient>(),
              context.read<SessionManager>(),
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => NotificationsViewModel(
            NotificationsRepository(
              context.read<LocalStorage>(),
              context.read<ApiClient>(),
              context.read<SessionManager>(),
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => SettingsViewModel(
            SettingsRepository(
              context.read<LocalStorage>(),
              context.read<ApiClient>(),
              context.read<SessionManager>(),
              context.read<AppConfig>(),
            ),
          ),
        ),
      ],
      child: child,
    );
  }
}

class TaskFiveApp extends StatelessWidget {
  const TaskFiveApp({
    super.key,
    this.config = const AppConfig(),
    this.apiClient,
    this.localStorage,
    this.connectivityService,
    this.locationService,
  });

  final AppConfig config;
  final ApiClient? apiClient;
  final LocalStorage? localStorage;
  final ConnectivityService? connectivityService;
  final LocationService? locationService;

  @override
  Widget build(BuildContext context) {
    return TaskFiveScope(
      config: config,
      apiClient: apiClient,
      localStorage: localStorage,
      connectivityService: connectivityService,
      locationService: locationService,
      child: MaterialApp(
        title: 'yeGamo',
        debugShowCheckedModeBanner: false,
        theme: YegamoTheme.light(reduceMotion: config.reduceMotion),
        themeMode: ThemeMode.light,
        initialRoute: AppRoutes.root,
        onGenerateRoute: TaskFiveRouteTable.generate,
        onUnknownRoute: TaskFiveRouteTable.unknownRoute,
        builder: TaskFiveRouteTable.shell(config),
      ),
    );
  }
}

abstract final class TaskFiveRouteTable {
  static Map<String, WidgetBuilder> routes() => <String, WidgetBuilder>{
    AppRoutes.root: (_) => const TaskFiveRootPage(),
    AppRoutes.splash: (_) => const SplashPage(),
    AppRoutes.onboarding: (_) => const OnboardingPage(),
    AppRoutes.permissions: (_) => const PermissionsPage(),
    AppRoutes.home: (_) => const HomePage(),
    AppRoutes.search: (_) => const SearchPage(),
    AppRoutes.nearby: (_) => const NearbyPage(),
    AppRoutes.planner: (_) => const PlannerPage(),
    AppRoutes.loading: (_) => const PlannerLoadingPage(),
    AppRoutes.alternatives: (_) => const AlternativesPage(),
    AppRoutes.departure: (_) => const DeparturePage(),
    AppRoutes.stepByStep: (_) => const PlannerStepsPage(),
    AppRoutes.activeJourney: (_) => const ActiveJourneyPage(),
    AppRoutes.getOffAlert: (_) => const GetOffAlertPage(),
    AppRoutes.saved: (_) => const SavedPage(),
    AppRoutes.commutes: (_) => const CommutesPage(),
    AppRoutes.notifications: (_) => const NotificationsPage(),
    AppRoutes.settings: (_) => const SettingsPage(),
  };

  /// Las pantallas se animan a sí mismas (`YgEnter`), por eso la ruta no
  /// añade transición propia, igual que el prototipo.
  static Route<void> generate(RouteSettings settings) {
    final builder = routes()[settings.name];
    if (builder == null) return unknownRoute(settings);
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => builder(context),
    );
  }

  /// Fondo «Bosque claro», mapa persistente y preferencia de movimiento.
  static TransitionBuilder shell(AppConfig config) {
    return (context, child) => YgMotionScope(
      reduceMotion: config.reduceMotion,
      child: ColoredBox(
        color: YgColors.page,
        child: YgMapHost(child: child),
      ),
    );
  }

  static Route<void> unknownRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const TaskFivePlaceholderPage(
        definition: AppRouteDefinition(
          name: '/unknown',
          title: 'Superficie no encontrada',
          icon: Icons.help_outline,
        ),
      ),
    );
  }
}

class TaskFivePlaceholderPage extends StatelessWidget {
  const TaskFivePlaceholderPage({super.key, required this.definition});

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
      body: SafeArea(
        child: Center(
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
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Esta ruta está registrada en la baseline. Su capacidad se habilitará en la siguiente vertical.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
