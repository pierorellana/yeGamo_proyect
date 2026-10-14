enum AppEnvironment { development, staging, production }

class AppConfig {
  static const defaultDevelopmentApiBaseUrl =
      'https://9hqbzkgw-3000.use.devtunnels.ms';
  static const defaultMapStyleUrl =
      'https://tiles.openfreemap.org/styles/positron';

  const AppConfig({
    this.apiBaseUrl = 'http://localhost:3000',
    this.environment = AppEnvironment.development,
    this.demoDataEnabled = false,
    this.reduceMotion = false,
    this.realMapEnabled = false,
    this.mapStyleUrl = '',
    this.mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.requestTimeout = const Duration(seconds: 15),
    this.maxRetries = 1,
  });

  factory AppConfig.fromEnvironment() {
    const rawEnvironment = String.fromEnvironment(
      'YEGAMO_ENV',
      defaultValue: 'development',
    );
    const requestedDemoData = bool.fromEnvironment(
      'YEGAMO_DEMO_DATA',
      defaultValue: false,
    );
    const reduceMotion = bool.fromEnvironment(
      'YEGAMO_REDUCE_MOTION',
      defaultValue: false,
    );
    const rawApiBaseUrl = String.fromEnvironment(
      'YEGAMO_API_BASE_URL',
      defaultValue: defaultDevelopmentApiBaseUrl,
    );
    const realMapEnabled = bool.fromEnvironment(
      'YEGAMO_REAL_MAP',
      defaultValue: true,
    );
    const mapStyleUrl = String.fromEnvironment(
      'YEGAMO_MAP_STYLE_URL',
      defaultValue: '',
    );
    const mapTileUrl = String.fromEnvironment(
      'YEGAMO_MAP_TILE_URL',
      defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    );

    final environment = AppEnvironment.values.firstWhere(
      (value) => value.name == rawEnvironment,
      orElse: () => AppEnvironment.development,
    );

    return AppConfig(
      apiBaseUrl: rawApiBaseUrl,
      environment: environment,
      demoDataEnabled:
          requestedDemoData && environment != AppEnvironment.production,
      reduceMotion: reduceMotion,
      realMapEnabled: realMapEnabled,
      mapStyleUrl: mapStyleUrl,
      mapTileUrl: mapTileUrl,
    );
  }

  final String apiBaseUrl;
  final AppEnvironment environment;
  final bool demoDataEnabled;
  final bool reduceMotion;
  final bool realMapEnabled;
  final String mapStyleUrl;
  final String mapTileUrl;
  final Duration requestTimeout;
  final int maxRetries;

  bool get isProduction => environment == AppEnvironment.production;

  Uri get apiBaseUri => Uri.parse(
    apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl,
  );
}
