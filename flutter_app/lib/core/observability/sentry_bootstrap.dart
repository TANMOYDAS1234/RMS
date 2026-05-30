// ─── Sentry Bootstrap ────────────────────────────────────────────────────────
// Wrap runApp() with this. Becomes a no-op when SENTRY_DSN dart-define is
// unset, so the same code runs in dev without local credentials.
//
// Uses the pure-Dart `sentry` package rather than `sentry_flutter` because
// the project's pubspec.yaml pins `jni: ^1.0.0` in dependency_overrides,
// which is incompatible with sentry_flutter's Android JNI bindings.

import 'package:flutter/foundation.dart';
import 'package:sentry/sentry.dart';

const _dsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
const _env = String.fromEnvironment('APP_ENV', defaultValue: 'development');

/// Runs [runner] inside a Sentry-instrumented zone when SENTRY_DSN is set,
/// otherwise just calls it directly.
Future<void> runWithSentry(Future<void> Function() runner) async {
  if (_dsn.isEmpty) {
    await runner();
    return;
  }
  await Sentry.init(
    (opts) {
      opts.dsn = _dsn;
      opts.environment = _env;
      opts.tracesSampleRate = 0.1;
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
