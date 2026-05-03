class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://rms-1-7hu6.onrender.com',
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'https://rms-1-7hu6.onrender.com',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration pollInterval   = Duration(seconds: 8);
  static const int maxRetries          = 3;
  static const Duration retryBaseDelay = Duration(seconds: 2);
}
