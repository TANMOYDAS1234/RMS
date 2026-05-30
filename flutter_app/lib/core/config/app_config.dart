/// Build-time URL the customer QR codes point to. The Flutter Web build
/// is served from this origin and main.dart's router maps
/// `/t/{tableId}?branch={branchId}` to QrOrderingScreen. Override at
/// build time:
///   --dart-define=QR_WEB_URL=https://your-domain.com
const String _qrWebUrl = String.fromEnvironment(
  'QR_WEB_URL',
  defaultValue: 'https://rms-backend-new-2.onrender.com',
);

class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://rms-backend-new-2.onrender.com',
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'https://rms-backend-new-2.onrender.com',
  );

  /// Public root the customer-facing QR codes point to. Each QR encodes
  /// `<qrWebBaseUrl>/t/<tableId>?branch=<branchId>`.
  static String get qrWebBaseUrl => _qrWebUrl;

  /// Build the public customer URL for a table. Manager prints this as
  /// a QR sticker; scanning it on a phone camera opens the customer
  /// ordering web app for that exact table.
  static String qrUrlForTable({
    required String tableId,
    required String branchId,
  }) =>
      '$_qrWebUrl/t/$tableId?branch=$branchId';

  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration pollInterval   = Duration(seconds: 8);
  static const int maxRetries          = 3;
  static const Duration retryBaseDelay = Duration(seconds: 2);
}
