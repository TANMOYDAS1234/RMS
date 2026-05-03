// ─── Dio HTTP Client ─────────────────────────────────────────────────────────

import 'package:dio/dio.dart';
import '../config/app_config.dart';

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

  dio.interceptors.addAll([
    _RetryInterceptor(dio),
    LogInterceptor(requestBody: true, responseBody: true),
  ]);

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

  bool _shouldRetry(DioException err) =>
      err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.receiveTimeout ||
      err.type == DioExceptionType.connectionError ||
      (err.response?.statusCode != null &&
          err.response!.statusCode! >= 500);
}
