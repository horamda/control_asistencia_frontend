class AppConfig {
  final String apiBaseUrl;
  final String mobileApiPrefix;
  final String mobileContractVersion;
  final String flavorLabel;
  final bool isProd;
  final int sessionIdleTimeoutMinutes;
  final int sessionMaxAgeHours;
  final int sessionProactiveRefreshMinutes;

  const AppConfig({
    required this.apiBaseUrl,
    required this.mobileApiPrefix,
    required this.mobileContractVersion,
    required this.flavorLabel,
    required this.isProd,
    required this.sessionIdleTimeoutMinutes,
    required this.sessionMaxAgeHours,
    required this.sessionProactiveRefreshMinutes,
  });

  Duration get sessionIdleTimeout =>
      Duration(minutes: sessionIdleTimeoutMinutes);
  Duration get sessionMaxAge => Duration(hours: sessionMaxAgeHours);
  Duration get sessionProactiveRefreshInterval =>
      Duration(minutes: sessionProactiveRefreshMinutes);

  static const _flavor = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'DEV',
  );
  static const _isProd = bool.fromEnvironment('APP_PROD', defaultValue: false);
  static const _isStage = _flavor == 'STAGE';
  static const _defaultIdleTimeoutMinutes = _isProd ? 20 : (_isStage ? 25 : 30);
  static const _defaultMaxAgeHours = _isProd ? 10 : (_isStage ? 10 : 12);
  static const _defaultProactiveRefreshMinutes = _isProd
      ? 8
      : (_isStage ? 8 : 10);

  // API_BASE_URL debe inyectarse en tiempo de compilacion:
  //   flutter build apk --dart-define=API_BASE_URL=https://tu-backend.com
  // Si no se inyecta, la URL queda vacia y la app falla al arrancar (ver
  // assert en AuthGatePage.initState). Esto es intencional: evita que la URL
  // real del backend quede expuesta en el binario distribuido.
  static const current = AppConfig(
    apiBaseUrl: String.fromEnvironment('API_BASE_URL'),
    mobileApiPrefix: String.fromEnvironment(
      'MOBILE_API_PREFIX',
      defaultValue: '/api/v1/mobile',
    ),
    mobileContractVersion: String.fromEnvironment(
      'MOBILE_CONTRACT_VERSION',
      defaultValue: '1.15.0',
    ),
    flavorLabel: _flavor,
    isProd: _isProd,
    sessionIdleTimeoutMinutes: int.fromEnvironment(
      'SESSION_IDLE_TIMEOUT_MINUTES',
      defaultValue: _defaultIdleTimeoutMinutes,
    ),
    sessionMaxAgeHours: int.fromEnvironment(
      'SESSION_MAX_AGE_HOURS',
      defaultValue: _defaultMaxAgeHours,
    ),
    sessionProactiveRefreshMinutes: int.fromEnvironment(
      'SESSION_PROACTIVE_REFRESH_MINUTES',
      defaultValue: _defaultProactiveRefreshMinutes,
    ),
  );
}
