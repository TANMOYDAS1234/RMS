// ─── Dio HTTP Client ─────────────────────────────────────────────────────────

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

/// Fires when any request returns 401. Subscribers (auth provider) should
/// clear local session state and route to login.
final StreamController<void> unauthorizedEvents =
    StreamController<void>.broadcast();

Dio createDioClient(String? authToken) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      },
    ),
  );

  dio.interceptors.add(_RetryInterceptor(dio));
  dio.interceptors.add(_UnauthorizedInterceptor());
  // Only log request/response bodies in debug builds — release builds would
  // otherwise spill passwords, JWTs, and Bearer tokens into device logs.
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }

  return dio;
}

class _RetryInterceptor extends Interceptor {
  final Dio dio;
  _RetryInterceptor(this.dio);

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final extra = err.requestOptions.extra;
    final retryCount = (extra['retryCount'] as int?) ?? 0;

    if (_shouldRetry(err) && retryCount < AppConfig.maxRetries) {
      final delay = AppConfig.retryBaseDelay * (retryCount + 1);
      await Future.delayed(delay);

      err.requestOptions.extra['retryCount'] = retryCount + 1;
      try {
        final response = await dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (e) {
        return handler.next(err);
      }
    }
    return handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    // Never retry 4xx — those are deterministic client errors.
    final status = err.response?.statusCode;
    if (status != null && status >= 400 && status < 500) return false;
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (status != null && status >= 500);
  }
}

/// Surfaces 401s to a global stream so auth providers can react (clear
/// session, route to /login). Without this, an expired token silently
/// failed every request and the UI looked logged-in-but-broken.
class _UnauthorizedInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      if (!unauthorizedEvents.isClosed) unauthorizedEvents.add(null);
    }
    handler.next(err);
  }
}
