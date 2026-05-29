// ─── Manager REST API ────────────────────────────────────────────────────────
// Centralizes the 9 manager endpoints + a few cross-controller paths the
// manager tabs use. Replaces inline `_xProvider` blobs in each tab file.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../presentation/state/auth_provider.dart';

class ManagerApi {
  final Dio _dio;
  ManagerApi(this._dio);

  // ── Reads ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> operations() => _map('/manager/operations');
  Future<List<Map<String, dynamic>>> tables() => _list('/manager/tables');
  Future<List<Map<String, dynamic>>> staff() => _list('/manager/staff');
  Future<List<Map<String, dynamic>>> kitchen() => _list('/manager/kitchen');
  Future<Map<String, dynamic>> inventoryStatus() => _map('/manager/inventory');
  Future<Map<String, dynamic>> report() => _map('/manager/report');
  Future<List<Map<String, dynamic>>> complaints() => _list('/manager/complaints');
  Future<List<Map<String, dynamic>>> pendingDiscounts() =>
      _list('/manager/discount-requests');

  // ── Order actions ───────────────────────────────────────────────────────
  Future<void> forceCloseOrder(String orderId, {required String idempotencyKey, int? expectedVersion}) =>
      _dio.patch(
        '/manager/order-action/force-close/$orderId',
        data: _body(expectedVersion: expectedVersion),
        options: _key(idempotencyKey),
      );

  Future<void> overrideOrderStatus(String orderId, String status,
          {required String idempotencyKey, int? expectedVersion}) =>
      _dio.patch(
        '/manager/order-action/override-status/$orderId',
        data: _body(extra: {'status': status}, expectedVersion: expectedVersion),
        options: _key(idempotencyKey),
      );

  Future<void> applyDiscount(String orderId, double percent, String reason,
          {required String idempotencyKey, int? expectedVersion}) =>
      _dio.patch(
        '/manager/order-action/discount/$orderId',
        data: _body(
          extra: {'discountPercent': percent, 'reason': reason},
          expectedVersion: expectedVersion,
        ),
        options: _key(idempotencyKey),
      );

  Future<void> prioritizeOrder(String orderId,
          {required String idempotencyKey, int? expectedVersion}) =>
      _dio.patch(
        '/manager/order-action/prioritize/$orderId',
        data: _body(expectedVersion: expectedVersion),
        options: _key(idempotencyKey),
      );

  // ── Tables ──────────────────────────────────────────────────────────────
  Future<void> updateTableStatus(String tableId, String status,
          {required String idempotencyKey}) =>
      _dio.patch(
        '/manager/tables/$tableId/status',
        data: {'status': status},
        options: _key(idempotencyKey),
      );

  // ── Inventory ───────────────────────────────────────────────────────────
  Future<void> reportShortage(String ingredientId, String note,
          {required String idempotencyKey}) =>
      _dio.post('/manager/inventory/$ingredientId/report-shortage',
          data: {'note': note}, options: _key(idempotencyKey));

  // ── Complaints ──────────────────────────────────────────────────────────
  Future<void> logComplaint({
    required String tableLabel,
    required String issue,
    String? category,
    String? severity,
    required String idempotencyKey,
  }) =>
      _dio.post('/manager/complaints',
          data: {
            'tableLabel': tableLabel,
            'issue': issue,
            if (category != null) 'category': category,
            if (severity != null) 'severity': severity,
          },
          options: _key(idempotencyKey));

  Future<void> resolveComplaint({
    required String orderId,
    required String complaintId,
    required String resolution,
    required String idempotencyKey,
  }) =>
      _dio.patch('/manager/complaints/resolve',
          data: {
            'orderId': orderId,
            'complaintId': complaintId,
            'resolution': resolution,
          },
          options: _key(idempotencyKey));

  // ── Helpers ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _list(String path) async {
    final res = await _dio.get(path);
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<Map<String, dynamic>> _map(String path) async {
    final res = await _dio.get(path);
    return Map<String, dynamic>.from(res.data);
  }

  Map<String, dynamic> _body({Map<String, dynamic>? extra, int? expectedVersion}) {
    return {
      if (extra != null) ...extra,
      if (expectedVersion != null) 'expectedVersion': expectedVersion,
    };
  }

  Options _key(String key) => Options(headers: {'Idempotency-Key': key});
}

final managerApiProvider = Provider.autoDispose<ManagerApi>((ref) {
  final token = ref.watch(authProvider).token;
  return ManagerApi(createDioClient(token));
});
