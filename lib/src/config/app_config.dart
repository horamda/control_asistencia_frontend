class AppConfig {
  final String apiBaseUrl;
  final String flavorLabel;
  final bool isProd;

  const AppConfig({
    required this.apiBaseUrl,
    required this.flavorLabel,
    required this.isProd,
  });

  static const current = AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:5000',
    ),
    flavorLabel: String.fromEnvironment('APP_FLAVOR', defaultValue: 'DEV'),
    isProd: bool.fromEnvironment('APP_PROD', defaultValue: false),
  );
}
