// ─── Remote Order Data Source ────────────────────────────────────────────────

import 'package:dio/dio.dart';
import '../../models/order_model.dart';
import '../../../core/errors/failures.dart';

class RemoteOrderDataSource {
  final Dio _dio;
  RemoteOrderDataSource(this._dio);

  Future<List<OrderModel>> getActiveOrders() async {
    try {
      final res = await _dio.get('/orders/active');
      return (res.data as List).map((j) => OrderModel.fromJson(j)).toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<OrderModel> updateStatus({
    required String orderId,
    required String status,
    required int version,
    required String idempotencyKey,
  }) async {
    try {
      final res = await _dio.patch(
        '/orders/$orderId/status',
        data: {'status': status, 'version': version},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return OrderModel.fromJson(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw VersionConflictFailure(e.response?.data['serverVersion'] ?? 0);
      }
      throw _mapError(e);
    }
  }

  Failure _mapError(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const NetworkFailure();
    }
    return ServerFailure(
      e.response?.data?['message'] ?? 'Server error',
      statusCode: e.response?.statusCode,
    );
  }
}
