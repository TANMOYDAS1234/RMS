import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../network/dio_client.dart';

// Must be top-level AND registered before runApp() — runs in a separate isolate
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); // required in background isolate
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;

  Future<void> init(String? authToken) async {
    // Request permission (iOS + Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // iOS foreground display options
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    // Get token and register with backend
    final token = await _messaging.getToken();
    if (token != null && authToken != null) {
      await _registerToken(token, authToken);
    }

    // Re-register on token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      if (authToken != null) _registerToken(newToken, authToken);
    });

    // Foreground message — show snackbar banner
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _showForegroundBanner(notification.title ?? '', notification.body ?? '');
    });
  }

  Future<void> _registerToken(String fcmToken, String authToken) async {
    try {
      final dio = createDioClient(authToken);
      await dio.patch('/users/me/fcm-token', data: {'fcmToken': fcmToken});
    } catch (_) {}
  }

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  void _showForegroundBanner(String title, String body) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        backgroundColor: const Color(0xFF1E1E2E),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(children: [
          const Icon(Icons.notifications_outlined, color: Color(0xFFE07B39), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              Text(body, style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 11)),
            ],
          )),
        ]),
      ),
    );
  }
}
