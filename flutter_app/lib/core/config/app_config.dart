class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://192.168.1.23:3000',
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'http://192.168.1.23:3000',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration pollInterval   = Duration(seconds: 8);
  static const int maxRetries          = 3;
  static const Duration retryBaseDelay = Duration(seconds: 2);
}
