import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../network/dio_client.dart';
import '../utils/idempotency.dart';

// Background entry point. Must be top-level AND registered before runApp() —
// runs in a separate isolate when a push arrives while the app is killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  _showLocalNotification(message);
}

final _localNotifications = FlutterLocalNotificationsPlugin();

// ── Channels ────────────────────────────────────────────────────────────────
//
// One Android channel per notification type so users can mute categories
// independently (e.g. silence low-stock noise but keep "order ready"
// alerts). The channel id MUST match the backend's CHANNEL_FOR mapping
// in notifications.service.ts — otherwise the channel falls back to a
// default low-importance one and the alert may be silently suppressed.
const _channels = <AndroidNotificationChannel>[
  AndroidNotificationChannel(
    'orders_new', 'New Orders',
    description: 'A new order has arrived in the kitchen',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'orders_ready', 'Orders Ready to Serve',
    description: 'Kitchen has marked an order ready for pickup',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'orders_served', 'Orders Served',
    description: 'Order delivered to table; ready to bill',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'payments', 'Payments',
    description: 'Customer payment received',
    importance: Importance.defaultImportance,
  ),
  AndroidNotificationChannel(
    'low_stock', 'Low Stock Alerts',
    description: 'Inventory item below threshold',
    importance: Importance.high,
  ),
];

/// Pull the channel id out of a remote message so the local notification
/// uses the right one. Falls back to a generic channel if the backend
/// didn't tag the message (shouldn't happen, defensive).
String _channelForMessage(RemoteMessage m) {
  final type = m.data['type'];
  switch (type) {
    case 'ORDER_CREATED':
      return 'orders_new';
    case 'ORDER_READY':
      return 'orders_ready';
    case 'ORDER_SERVED':
      return 'orders_served';
    case 'PAYMENT_RECEIVED':
      return 'payments';
    case 'LOW_STOCK':
      return 'low_stock';
    default:
      return 'orders_new';
  }
}

void _showLocalNotification(RemoteMessage message) {
  final n = message.notification;
  if (n == null) return;
  final channelId = _channelForMessage(message);
  final channel = _channels.firstWhere(
    (c) => c.id == channelId,
    orElse: () => _channels.first,
  );
  _localNotifications.show(
    message.hashCode,
    n.title,
    n.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id, channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(presentSound: true),
    ),
  );
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;
  static const _kDeviceIdKey = 'fcm_device_id';

  /// Tapped-notification callback. Wire this in main.dart so e.g. an
  /// ORDER_READY tap can pop the waiter into the right table's screen.
  void Function(RemoteMessage message)? onMessageOpened;

  Future<String> _resolveDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kDeviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final fresh = const Uuid().v4();
    await prefs.setString(_kDeviceIdKey, fresh);
    return fresh;
  }

  String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }

  Future<void> init(String? authToken) async {
    // Register every channel up front. createNotificationChannel is
    // idempotent — calling it on repeat launches is safe.
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      for (final c in _channels) {
        await androidPlugin.createNotificationChannel(c);
      }
    }

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    final settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    final token = await _messaging.getToken();
    if (token != null && authToken != null) {
      await _registerToken(token, authToken);
    }
    _messaging.onTokenRefresh.listen((newToken) {
      if (authToken != null) _registerToken(newToken, authToken);
    });

    // Foreground: show banner + local notification (FCM doesn't show one
    // for us when the app is in the foreground).
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
      final n = message.notification;
      if (n != null) {
        _showForegroundBanner(n.title ?? '', n.body ?? '');
      }
    });

    // Background → foreground: user tapped the notification. Route them
    // to the right place via the data payload.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onMessageOpened?.call(message);
    });

    // Cold start: the user tapped a notification that launched the app.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // Defer one frame so the navigator is ready.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onMessageOpened?.call(initial);
      });
    }
  }

  Future<void> _registerToken(String fcmToken, String authToken) async {
    try {
      final dio = createDioClient(authToken);
      final deviceId = await _resolveDeviceId();
      // The backend's IdempotencyInterceptor requires a key on every PATCH.
      // Pin it to (token, deviceId) so a retry of the same registration
      // is a true no-op server-side instead of a fresh write.
      await dio.patch(
        '/users/me/fcm-token',
        data: {
          'fcmToken': fcmToken,
          'deviceId': deviceId,
          'platform': _platform(),
        },
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('fcm-token-${fcmToken.hashCode}-${deviceId.hashCode}'),
        }),
      );
    } catch (_) {
      // Best-effort — losing a push registration shouldn't crash the app.
    }
  }

  /// Called from the auth provider on logout so the next user signed into
  /// this device doesn't keep receiving the previous account's pushes.
  Future<void> clearToken(String authToken) async {
    try {
      final dio = createDioClient(authToken);
      await dio.patch(
        '/users/me/fcm-token/clear',
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('fcm-clear'),
        }),
      );
    } catch (_) {}
    try {
      await _messaging.deleteToken();
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
