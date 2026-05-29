// ─── Admin REST API ──────────────────────────────────────────────────────────
// One class per panel, one method per endpoint. Eliminates the prior 14+
// inline FutureProvider blobs that each rebuilt their own Dio client and
// repeated the same `createDioClient(ref.watch(authProvider).token)` pattern.
//
// Every mutating method takes an `idempotencyKey` so callers can pin a
// stable UUID per logical user action (see core/utils/idempotency.dart).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../presentation/state/auth_provider.dart';

class AdminApi {
  final Dio _dio;
  AdminApi(this._dio);

  // ── Analytics & reports ─────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> sales({DateTime? from, DateTime? to}) =>
      _listQ('/analytics/sales', _range(from, to));
  Future<List<Map<String, dynamic>>> topItems({DateTime? from, DateTime? to}) =>
      _listQ('/analytics/top-items', {..._range(from, to), 'limit': '10'});
  Future<List<Map<String, dynamic>>> peakHours({DateTime? from, DateTime? to}) =>
      _listQ('/analytics/peak-hours', _range(from, to));
  Future<List<Map<String, dynamic>>> staffPerformance(
          {DateTime? from, DateTime? to}) =>
      _listQ('/analytics/staff-performance', _range(from, to));

  // ── Admin-only endpoints ────────────────────────────────────────────────
  Future<Map<String, dynamic>> systemHealth() => _map('/admin/system-health');
  Future<Map<String, dynamic>> financialSummary() => _map('/admin/financial-summary');
  Future<List<Map<String, dynamic>>> transactions() => _list('/admin/transactions');
  Future<Map<String, dynamic>> profitMargin() => _map('/admin/profit-margin');
  Future<Map<String, dynamic>> auditLog({int skip = 0, int limit = 100}) async {
    final res = await _dio.get('/admin/audit-log',
        queryParameters: {'skip': skip, 'limit': limit});
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> forceCloseOrder(String orderId, {required String idempotencyKey}) =>
      _dio.patch('/admin/orders/$orderId/force-close',
          options: _key(idempotencyKey));

  Future<void> refundBill(String billId, {required String idempotencyKey}) =>
      _dio.patch('/admin/billing/$billId/refund', options: _key(idempotencyKey));

  Future<void> resetPassword(String userId, String newPassword,
          {required String idempotencyKey}) =>
      _dio.post('/admin/users/$userId/reset-password',
          data: {'newPassword': newPassword}, options: _key(idempotencyKey));

  // ── Shared resources used by admin tabs ─────────────────────────────────
  Future<List<Map<String, dynamic>>> users() => _list('/users');
  Future<List<Map<String, dynamic>>> branches() => _list('/branches');
  Future<List<Map<String, dynamic>>> menuForBranch(String branchId) =>
      _list('/menu/branch/$branchId/admin');
  Future<List<Map<String, dynamic>>> inventory() => _list('/inventory');
  Future<List<Map<String, dynamic>>> activeOrders() => _list('/orders/active');

  // ── User CRUD ───────────────────────────────────────────────────────────
  Future<void> createUser(Map<String, dynamic> data,
          {required String idempotencyKey}) =>
      _dio.post('/users', data: data, options: _key(idempotencyKey));

  Future<void> updateUser(String userId, Map<String, dynamic> data,
          {required String idempotencyKey}) =>
      _dio.patch('/users/$userId', data: data, options: _key(idempotencyKey));

  Future<void> deleteUser(String userId, {required String idempotencyKey}) =>
      _dio.delete('/users/$userId', options: _key(idempotencyKey));

  Future<void> uploadUserPhoto(String userId, FormData formData,
          {required String idempotencyKey}) =>
      _dio.post('/users/$userId/photo',
          data: formData, options: _key(idempotencyKey));

  // ── Branch CRUD + features ──────────────────────────────────────────────
  Future<void> createBranch(Map<String, dynamic> data,
          {required String idempotencyKey}) =>
      _dio.post('/branches', data: data, options: _key(idempotencyKey));

  Future<void> updateBranch(String branchId, Map<String, dynamic> data,
          {required String idempotencyKey}) =>
      _dio.patch('/branches/$branchId',
          data: data, options: _key(idempotencyKey));

  Future<void> deleteBranch(String branchId,
          {required String idempotencyKey}) =>
      _dio.delete('/branches/$branchId', options: _key(idempotencyKey));

  Future<void> toggleBranchFeature(
          String branchId, String feature, bool value,
          {required String idempotencyKey}) =>
      _dio.patch('/branches/$branchId/features',
          data: {feature: value}, options: _key(idempotencyKey));

  // ── Inventory CRUD ──────────────────────────────────────────────────────
  Future<void> createIngredient(Map<String, dynamic> data,
          {required String idempotencyKey}) =>
      _dio.post('/inventory', data: data, options: _key(idempotencyKey));

  Future<void> adjustIngredient(String ingredientId, Map<String, dynamic> data,
          {required String idempotencyKey}) =>
      _dio.patch('/inventory/$ingredientId/adjust',
          data: data, options: _key(idempotencyKey));

  Future<void> deleteIngredient(String ingredientId,
          {required String idempotencyKey}) =>
      _dio.delete('/inventory/$ingredientId', options: _key(idempotencyKey));

  // ── Menu CRUD ───────────────────────────────────────────────────────────
  Future<Response<dynamic>> createMenuItem(Map<String, dynamic> data,
          {required String idempotencyKey}) =>
      _dio.post('/menu', data: data, options: _key(idempotencyKey));

  Future<void> updateMenuItem(String itemId, Map<String, dynamic> data,
          {required String idempotencyKey}) =>
      _dio.patch('/menu/$itemId', data: data, options: _key(idempotencyKey));

  Future<void> deleteMenuItem(String itemId,
          {required String idempotencyKey}) =>
      _dio.delete('/menu/$itemId', options: _key(idempotencyKey));

  Future<void> uploadMenuImage(String itemId, FormData formData,
          {required String idempotencyKey}) =>
      _dio.post('/menu/$itemId/image',
          data: formData, options: _key(idempotencyKey));

  Future<void> uploadMenuGlb(String itemId, FormData formData,
          {required String idempotencyKey}) =>
      _dio.post('/menu/$itemId/glb',
          data: formData, options: _key(idempotencyKey));

  // ── Profile (current user) ──────────────────────────────────────────────
  Future<Map<String, dynamic>> me() => _map('/auth/me');

  Future<void> updateMe(Map<String, dynamic> data,
          {required String idempotencyKey}) =>
      _dio.patch('/auth/me', data: data, options: _key(idempotencyKey));

  // ── Helpers ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _list(String path) async {
    final res = await _dio.get(path);
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<List<Map<String, dynamic>>> _listQ(
      String path, Map<String, dynamic> q) async {
    final res = await _dio.get(path, queryParameters: q);
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<Map<String, dynamic>> _map(String path) async {
    final res = await _dio.get(path);
    return Map<String, dynamic>.from(res.data);
  }

  Map<String, dynamic> _range(DateTime? from, DateTime? to) => {
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      };

  Options _key(String key) => Options(headers: {'Idempotency-Key': key});
}

/// Token-aware AdminApi provider. Watches authProvider so the Dio client
/// is rebuilt when the token changes — no more stale 401-and-die paths.
final adminApiProvider = Provider.autoDispose<AdminApi>((ref) {
  final token = ref.watch(authProvider).token;
  return AdminApi(createDioClient(token));
});
