// ─── Platform-conditional window.open() helper ──────────────────────────────
//
// On web → opens a URL in a new tab via window.open(...).
// On mobile/desktop → no-op (the AR feature is web-only for now).
//
// The conditional export means the mobile build never compiles
// dart:html — keeping it portable across all platforms.

export 'web_window_stub.dart'
    if (dart.library.html) 'web_window_web.dart';
