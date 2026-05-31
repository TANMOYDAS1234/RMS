// ─── FCM Service — platform-conditional facade ──────────────────────────────
//
// Resolves to:
//   - fcm_service_io.dart   on Android/iOS/desktop
//   - fcm_service_web.dart  on Flutter Web (stubbed)
//
// firebase_messaging_web is currently incompatible with current
// firebase_core_web ('PromiseJsImpl' / 'handleThenable' compile errors),
// and web customers don't need push anyway. Everything else in the app
// just imports this file.

export 'fcm_service_io.dart'
    if (dart.library.html) 'fcm_service_web.dart';
