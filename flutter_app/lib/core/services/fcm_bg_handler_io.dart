// ─── FCM Background Handler — IO (Android/iOS) ──────────────────────────────
//
// The actual firebase_messaging.onBackgroundMessage registration. Imported
// on mobile only via the conditional `if (dart.library.html)` directive in
// main.dart, so the web build never compiles this file.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'fcm_service_io.dart';

void registerBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}
