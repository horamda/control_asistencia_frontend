class AppConfig {
  final String apiBaseUrl;
  final String mobileApiPrefix;
  final String mobileContractVersion;
  final String flavorLabel;
  final bool isProd;

  const AppConfig({
    required this.apiBaseUrl,
    required this.mobileApiPrefix,
    required this.mobileContractVersion,
    required this.flavorLabel,
    required this.isProd,
  });

  static const current = AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://control-asistencia-backend-8gle.onrender.com',
    ),
    mobileApiPrefix: String.fromEnvironment(
      'MOBILE_API_PREFIX',
      defaultValue: '/api/v1/mobile',
    ),
    mobileContractVersion: String.fromEnvironment(
      'MOBILE_CONTRACT_VERSION',
      defaultValue: '1.9.0',
    ),
    flavorLabel: String.fromEnvironment('APP_FLAVOR', defaultValue: 'DEV'),
    isProd: bool.fromEnvironment('APP_PROD', defaultValue: false),
  );
}
