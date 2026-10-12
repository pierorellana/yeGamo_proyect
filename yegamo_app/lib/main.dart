import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'env/config/app_config.dart';
import 'env/theme/yegamo_theme.dart';
import 'shared/location/location_service.dart';
import 'shared/navigation/app_routes.dart';
import 'shared/services/api_client.dart';
import 'shared/services/connectivity_service.dart';
import 'shared/storage/local_storage.dart';
import 'modules/onboarding/task_five_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final preferences = await SharedPreferences.getInstance();
  final storage = SharedLocalStorage(preferences: preferences);

  runApp(YeGamoApp(config: config, localStorage: storage));
}

class YeGamoApp extends StatelessWidget {
  const YeGamoApp({
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
