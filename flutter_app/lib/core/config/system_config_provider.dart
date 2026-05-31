// ─── Runtime System Config ───────────────────────────────────────────────────
//
// One round-trip at startup to GET /system/config so the app doesn't need
// build-time --dart-define flags for anything that could change between
// deploys (QR web origin, Razorpay key, etc.).
//
// Layered fallbacks so the app stays usable even when the config endpoint
// is down:
//   1. Backend's /system/config response
//   2. When running on web → window.location.origin (Uri.base)
//   3. AppConfig.baseUrl (compile-time default)
//
// All three are wrapped behind one provider: `systemConfigProvider`.
// QR-generation code reads `runtimeQrWebBaseUrlProvider` which already
// resolves the fallback chain.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_config.dart';

class SystemConfig {
  /// Where the customer QR codes should point to. Same origin that serves
  /// the Flutter Web build of QrOrderingScreen.
  final String qrWebBaseUrl;

  /// The API origin the server thinks it is at. Diagnostic only — clients
  /// should keep using AppConfig.baseUrl for their own API calls.
  final String apiBaseUrl;

  /// Razorpay sandbox key + enabled flag. Forwarded from the existing
  /// /billing/razorpay/config endpoint so callers have one config source
  /// instead of two.
  final String razorpayKeyId;
  final bool razorpayEnabled;
  // True only when BOTH KEY_ID and KEY_SECRET are configured server-side.
  // Customer web Pay Now uses this — false means the operator deployed
  // without the SECRET and the button hides itself instead of showing a
  // broken flow.
  final bool razorpayWebEnabled;
  final String razorpayEnvironment;

  /// 'development' / 'production'. Used by Sentry / observability tags.
  final String environment;

  const SystemConfig({
    required this.qrWebBaseUrl,
    required this.apiBaseUrl,
    required this.razorpayKeyId,
    required this.razorpayEnabled,
    required this.razorpayWebEnabled,
    required this.razorpayEnvironment,
    required this.environment,
  });

  factory SystemConfig.fallback() => SystemConfig(
        qrWebBaseUrl: _fallbackQrBase(),
        apiBaseUrl: AppConfig.baseUrl,
        razorpayKeyId: '',
        razorpayEnabled: false,
        razorpayWebEnabled: false,
        razorpayEnvironment: 'sandbox',
        environment: 'unknown',
      );

  factory SystemConfig.fromJson(Map<String, dynamic> j) {
    final raz = (j['razorpay'] as Map?) ?? const {};
    final fromServer = (j['qrWebBaseUrl'] as String?)?.trim() ?? '';
    return SystemConfig(
      // Server-provided URL wins. Empty string → fall back to client-side
      // detection (same-origin on web, AppConfig on mobile).
      qrWebBaseUrl: fromServer.isNotEmpty ? fromServer : _fallbackQrBase(),
      apiBaseUrl: (j['apiBaseUrl'] as String?) ?? AppConfig.baseUrl,
      razorpayKeyId: (raz['keyId'] as String?) ?? '',
      razorpayEnabled: (raz['enabled'] as bool?) ?? false,
      // Falls back to razorpayEnabled when an older backend doesn't yet
      // expose `webEnabled` — that preserves the previous behaviour for
      // operators who haven't redeployed.
      razorpayWebEnabled: (raz['webEnabled'] as bool?) ?? (raz['enabled'] as bool?) ?? false,
      razorpayEnvironment: (raz['environment'] as String?) ?? 'sandbox',
      environment: (j['environment'] as String?) ?? 'unknown',
    );
  }
}

/// Resolve the QR web URL without a server round-trip:
///  - on Flutter Web: use the page's own origin (Uri.base) so the QR code
///    encodes whatever domain the customer is currently sitting on.
///  - on mobile: use AppConfig.baseUrl (compile-time default).
String _fallbackQrBase() {
  if (kIsWeb) {
    final base = Uri.base;
    final origin = '${base.scheme}://${base.authority}';
    if (origin.isNotEmpty && origin != '://') return origin;
  }
  return AppConfig.baseUrl;
}

/// Single-fetch provider. Errors fall through to a defaulted config so the
/// app keeps working — the QR will still resolve to *something* sensible.
final systemConfigProvider = FutureProvider<SystemConfig>((ref) async {
  try {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));
    final res = await dio.get('/system/config');
    return SystemConfig.fromJson(Map<String, dynamic>.from(res.data));
  } catch (_) {
    return SystemConfig.fallback();
  }
});

/// Sync convenience: the current QR web base URL, with fallback. Use this
/// from QR-generation widgets so they never block on the network.
final runtimeQrWebBaseUrlProvider = Provider<String>((ref) {
  final cfg = ref.watch(systemConfigProvider);
  return cfg.maybeWhen(
    data: (c) => c.qrWebBaseUrl,
    orElse: () => _fallbackQrBase(),
  );
});
