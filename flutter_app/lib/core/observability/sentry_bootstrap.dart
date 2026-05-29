// ─── Sentry Bootstrap ────────────────────────────────────────────────────────
// Wrap runApp() with this. Becomes a no-op when SENTRY_DSN dart-define is
// unset, so the same code runs in dev without local credentials.

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _dsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
const _env = String.fromEnvironment('APP_ENV', defaultValue: 'development');

/// Runs [runner] inside a Sentry-instrumented zone when SENTRY_DSN is set,
/// otherwise just calls it directly.
Future<void> runWithSentry(Future<void> Function() runner) async {
  if (_dsn.isEmpty) {
    await runner();
    return;
  }
  await SentryFlutter.init(
    (opts) {
      opts.dsn = _dsn;
      opts.environment = _env;
      opts.tracesSampleRate = 0.1;
      // Don't ship request bodies that may contain JWTs/passwords.
      opts.sendDefaultPii = false;
      opts.attachStacktrace = true;
      opts.beforeSend = (event, hint) {
        // Strip headers so JWTs / Idempotency-Keys don't leave the device.
        if (event.request != null) {
          event.request!.headers.clear();
        }
        return event;
      };
    },
    appRunner: runner,
  );
}

/// Report a caught error (e.g. inside a Dio interceptor) without crashing.
void reportError(Object error, StackTrace? stack) {
  if (_dsn.isEmpty) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[Sentry no-op] $error');
    }
    return;
  }
  Sentry.captureException(error, stackTrace: stack);
}
