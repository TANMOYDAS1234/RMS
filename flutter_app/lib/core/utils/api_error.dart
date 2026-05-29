import 'package:dio/dio.dart';

/// Map a DioException (or any thrown error) to a user-friendly string.
/// Hides stacks and Dio internals from snackbars.
String describeApiError(Object error) {
  if (error is DioException) {
    final res = error.response;
    if (res != null) {
      final status = res.statusCode ?? 0;
      final body = res.data;
      final serverMsg = _extractServerMessage(body);
      switch (status) {
        case 400:
          return serverMsg ?? 'Bad request — check the fields and try again.';
        case 401:
          return 'Session expired. Please sign in again.';
        case 403:
          return 'You do not have permission for this action.';
        case 404:
          return serverMsg ?? 'Not found.';
        case 409:
          return serverMsg ?? 'Another change happened first. Refresh and try again.';
        case 429:
          return 'Too many requests. Slow down and try again.';
        case 500:
        case 502:
        case 503:
        case 504:
          return 'Server hiccup — please retry in a moment.';
        default:
          return serverMsg ?? 'Request failed ($status).';
      }
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Network timeout — check your connection.';
      case DioExceptionType.connectionError:
        return 'Can\'t reach the server. Check your connection.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      default:
        return 'Network error.';
    }
  }
  return 'Unexpected error: ${error.runtimeType}';
}

String? _extractServerMessage(dynamic body) {
  if (body is String && body.isNotEmpty) return body;
  if (body is Map) {
    final msg = body['message'];
    if (msg is String) return msg;
    if (msg is Map) {
      final inner = msg['message'];
      if (inner is String) return inner;
    }
    if (msg is List && msg.isNotEmpty && msg.first is String) return msg.join('\n');
  }
  return null;
}

bool isVersionConflict(Object error) =>
    error is DioException && error.response?.statusCode == 409;

bool isUnauthorized(Object error) =>
    error is DioException && error.response?.statusCode == 401;
