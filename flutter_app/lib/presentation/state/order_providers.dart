import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/order_entity.dart';
import '../../core/services/websocket_service.dart';
import '../../core/services/sync_engine.dart';
import '../../core/network/dio_client.dart';
import '../../data/models/order_model.dart';
import 'auth_provider.dart';

// ── Dashboard metrics ─────────────────────────────────────────────────────────
class DashboardMetrics {
  final int activeOrders;
  final int occupiedTables;
  final int totalTables;
  final double revenue;

  const DashboardMetrics({
    required this.activeOrders,
    required this.occupiedTables,
    required this.totalTables,
    required this.revenue,
  });
}

final dashboardMetricsProvider = Provider<DashboardMetrics>((ref) {
  final orders = ref.watch(liveOrdersProvider);
  final tablesAsync = ref.watch(tablesCountProvider);
  final active = orders
      .where((o) => o.status != OrderStatus.closed && o.status != OrderStatus.paid)
      .length;
  final revenue = orders
      .where((o) => o.status == OrderStatus.paid || o.status == OrderStatus.billed)
      .fold<double>(0, (sum, o) => sum + o.total);
  return DashboardMetrics(
    activeOrders: active,
    occupiedTables: active,
    totalTables: tablesAsync.value ?? 0,
    revenue: revenue,
  );
});

final tablesCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) return 0;
  final dio = createDioClient(token);
  final res = await dio.get('/tables');
  return (res.data as List).length;
});

// ── Live orders state ─────────────────────────────────────────────────────────
class LiveOrdersNotifier extends StateNotifier<List<OrderEntity>> {
  final Ref _ref;
  StreamSubscription? _wsSub;
  Timer? _pollTimer;
  final _uuid = const Uuid();

  LiveOrdersNotifier(this._ref) : super([]) {
    _fetchFromServer();
    _listenToWebSocket();
    _startPollingFallback();
  }

  Future<void> _fetchFromServer() async {
    try {
      final token = _ref.read(authProvider).token;
      if (token == null) return;
      final dio = createDioClient(token);
      final res = await dio.get('/orders/active');
      final orders = (res.data as List)
          .map((j) => OrderModel.fromJson(j).toEntity())
          .toList();
      state = orders;
    } catch (_) {}
  }

  void _listenToWebSocket() {
    final ws = _ref.read(webSocketServiceProvider);
    _wsSub = ws.eventStream.listen((event) {
      switch (event['event']) {
        case 'order:updated':
          _handleOrderUpdate(event['data']);
        case 'order:created':
          _handleOrderCreated(event['data']);
        case 'kitchen:progress':
          _handleKitchenProgress(event['data']);
      }
    });
  }

  void _startPollingFallback() {
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      final ws = _ref.read(webSocketServiceProvider);
      if (ws.state != SocketState.connected) _fetchFromServer();
    });
  }

  void _handleOrderUpdate(dynamic data) {
    if (data == null) return;
    final incoming = OrderModel.fromJson(Map<String, dynamic>.from(data)).toEntity();
    state = state.map((o) {
      if (o.id != incoming.id) return o;
      if (incoming.version < o.version) return o;
      return incoming;
    }).toList();
  }

  void _handleOrderCreated(dynamic data) {
    if (data == null) return;
    final incoming = OrderModel.fromJson(Map<String, dynamic>.from(data)).toEntity();
    if (!state.any((o) => o.id == incoming.id)) {
      state = [...state, incoming];
    }
  }

  void _handleKitchenProgress(dynamic data) {
    if (data == null) return;
    final orderId = data['orderId'] as String?;
    final itemId = data['itemId'] as String?;
    final progress = (data['progress'] as num?)?.toDouble();
    if (orderId == null || itemId == null || progress == null) return;
    state = state.map((o) {
      if (o.id != orderId) return o;
      final updatedItems = o.items.map((item) {
        if (item.id != itemId) return item;
        return item.copyWith(progress: progress);
      }).toList();
      return o.copyWith(items: updatedItems);
    }).toList();
  }

  Future<void> updateStatus(String orderId, OrderStatus newStatus) async {
    final idx = state.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final order = state[idx];
    if (!order.status.canTransitionTo(newStatus)) return;

    final optimistic = order.copyWith(
      status: newStatus,
      version: order.version + 1,
      syncStatus: SyncStatus.pending,
    );
    state = [...state]..[idx] = optimistic;

    final idempotencyKey = _uuid.v4();
    try {
      final token = _ref.read(authProvider).token;
      final dio = createDioClient(token);
      final res = await dio.patch(
        '/orders/$orderId/status',
        data: {'status': newStatus.statusName, 'version': order.version},
        options: _opts({'Idempotency-Key': idempotencyKey}),
      );
      final updated = OrderModel.fromJson(res.data).toEntity();
      state = [...state]..[idx] = updated;
    } catch (_) {
      state = [...state]..[idx] = order.copyWith(syncStatus: SyncStatus.conflict);
      await _ref.read(syncEngineProvider).enqueue(
        endpoint: '/orders/$orderId/status',
        method: 'PATCH',
        payload: {'status': newStatus.statusName, 'version': order.version},
        idempotencyKey: idempotencyKey,
      );
    }
  }

  Future<void> createOrder({
    required String tableId,
    required String tableLabel,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final idempotencyKey = _uuid.v4();
    try {
      final token = _ref.read(authProvider).token;
      final dio = createDioClient(token);
      final res = await dio.post(
        '/orders',
        data: {'tableId': tableId, 'tableLabel': tableLabel, 'items': items, if (notes != null) 'notes': notes},
        options: _opts({'Idempotency-Key': idempotencyKey}),
      );
      final created = OrderModel.fromJson(res.data).toEntity();
      state = [created, ...state];
    } catch (_) {
      await _ref.read(syncEngineProvider).enqueue(
        endpoint: '/orders',
        method: 'POST',
        payload: {'tableId': tableId, 'tableLabel': tableLabel, 'items': items},
        idempotencyKey: idempotencyKey,
      );
    }
  }

  dynamic _opts(Map<String, String> headers) => Options(headers: headers);

  Future<void> refresh() => _fetchFromServer();

  @override
  void dispose() {
    _wsSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}

final liveOrdersProvider =
    StateNotifierProvider<LiveOrdersNotifier, List<OrderEntity>>(
  (ref) => LiveOrdersNotifier(ref),
);
