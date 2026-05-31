// ─── FCM Service — Web Stub ──────────────────────────────────────────────────
//
// firebase_messaging_web has a long-running incompatibility with current
// firebase_core_web (PromiseJsImpl, handleThenable). Customers using the
// QR ordering screen on web don't need push notifications anyway — the
// app uses WebSocket events when foregrounded, and there's no
// "backgrounded" state to wake.
//
// This stub matches the public API of FcmService so the rest of the app
// can just `import 'fcm_service.dart'` and not branch on platform.

import 'package:flutter/material.dart';

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  /// Web has no FCM tap routing; left as a public hook to match the API.
  // ignore: unused_field, prefer_function_declarations_over_variables
  void Function(Map<String, dynamic> data)? onMessageOpened;

  Future<void> init(String? authToken) async {
    // No-op on web.
  }

  Future<void> clearToken(String authToken) async {
    // No-op on web.
  }

  /// Foreground banner — the staff app uses this on mobile but we expose
  /// the same key on web so main.dart can wire MaterialApp.scaffoldMessenger
  /// without branching.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();
}

/// Stubbed background handler — never invoked on web.
Future<void> firebaseMessagingBackgroundHandler(dynamic message) async {}
