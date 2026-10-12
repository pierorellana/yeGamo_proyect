enum AppEnvironment { development, staging, production }

class AppConfig {
  const AppConfig({
    this.apiBaseUrl = 'http://localhost:3000',
    this.environment = AppEnvironment.development,
    this.demoDataEnabled = false,
    this.reduceMotion = false,
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
      defaultValue: 'http://localhost:3000',
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
    );
  }

  final String apiBaseUrl;
  final AppEnvironment environment;
  final bool demoDataEnabled;
  final bool reduceMotion;
  final Duration requestTimeout;
  final int maxRetries;

  bool get isProduction => environment == AppEnvironment.production;

  Uri get apiBaseUri => Uri.parse(
    apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl,
  );
}
