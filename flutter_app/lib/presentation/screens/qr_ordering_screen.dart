// ─── QR Customer Ordering Screen (Flutter Web PWA) ───────────────────────────
// Entry: https://yourdomain.com/t/{tableId}?branch={branchId}
// Handles: session resume, feature-flag check, menu browse, order placement, tracking

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/services/websocket_service.dart';
import '../../core/utils/api_error.dart';
import '../state/menu_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _sessionProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
final _qrOrdersProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);
final _qrEnabledProvider = StateProvider<bool>((ref) => false);

/// Persistent device id keyed in SharedPreferences. Previously this minted
/// a fresh UUID on every screen build, which meant every reload looked like
/// a new diner to the backend — sessions kept duplicating, the participants
/// list ballooned, and 'who's at this table' was unanswerable.
const _kDeviceIdKey = 'qr_device_id';
Future<String> _resolveDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_kDeviceIdKey);
  if (existing != null && existing.isNotEmpty) return existing;
  final fresh = const Uuid().v4();
  await prefs.setString(_kDeviceIdKey, fresh);
  return fresh;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class QrOrderingScreen extends ConsumerStatefulWidget {
  final String tableId;
  final String branchId;

  const QrOrderingScreen({
    super.key,
    required this.tableId,
    required this.branchId,
  });

  @override
  ConsumerState<QrOrderingScreen> createState() => _QrOrderingScreenState();
}

class _QrOrderingScreenState extends ConsumerState<QrOrderingScreen> {
  final _dio = createDioClient(null);
  final _uuid = const Uuid();
  bool _loading = true;
  String? _error;
  int _tabIndex = 0;
  Timer? _activityTimer;
  String? _deviceId;
  StreamSubscription<WsEvent>? _wsSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // 0. Resolve persistent device id (one-time UUID per browser).
      _deviceId = await _resolveDeviceId();

      // 1. Check feature flag (also enforced server-side at session creation).
      final flagRes = await _dio.get('/branches/${widget.branchId}/qr-enabled');
      final enabled = flagRes.data['enabled'] as bool;
      ref.read(_qrEnabledProvider.notifier).state = enabled;

      // 2. Get or create session. Idempotency key is stable per device+table
      //    so a refresh doesn't spawn a parallel session.
      final sessionRes = await _dio.post(
        '/sessions/scan',
        data: {
          'tableId': widget.tableId,
          'branchId': widget.branchId,
          'deviceId': _deviceId,
        },
        options: Options(headers: {
          'Idempotency-Key': 'scan-${widget.tableId}-$_deviceId',
        }),
      );
      ref.read(_sessionProvider.notifier).state =
          Map<String, dynamic>.from(sessionRes.data);

      // 3. Load existing orders for this session via public bill endpoint.
      await _loadSessionBill();

      // 4. Connect WS — join the per-table room so we only receive events
      //    for our own table, no cross-tenant leak.
      ref.read(webSocketServiceProvider).connect(
            '',
            tableId: widget.tableId,
            branchId: widget.branchId,
          );
      _wsSub = ref.read(webSocketServiceProvider).eventStream.listen((evt) {
        if (evt.event == 'order:updated' || evt.event == 'order:created' ||
            evt.event == 'kitchen:progress') {
          _loadSessionBill();
        }
      });

      // 5. Refresh session TTL on activity — UUID key per tick so the
      //    server doesn't dedup against the previous refresh.
      _activityTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        final session = ref.read(_sessionProvider);
        if (session != null) {
          _dio.patch('/sessions/${session['_id']}/refresh',
              options: Options(headers: {
                'Idempotency-Key': _uuid.v4(),
              }));
        }
      });
    } catch (e) {
      setState(() => _error = describeApiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Pulls the running tab from the new public /sessions/:id/bill endpoint,
  /// which aggregates every order linked to the session. Cheaper than N
  /// round-trips to /orders/:id and works without staff auth.
  Future<void> _loadSessionBill() async {
    final session = ref.read(_sessionProvider);
    if (session == null) return;
    try {
      final res = await _dio.get('/sessions/${session['_id']}/bill');
      final orders = List<Map<String, dynamic>>.from(res.data['orders'] ?? []);
      ref.read(_qrOrdersProvider.notifier).state = orders;
    } catch (_) {
      // Best-effort; the user will see stale data and the next tick retries.
    }
  }

  @override
  void dispose() {
    _activityTimer?.cancel();
    _wsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _LoadingView();
    if (_error != null) return _ErrorView(error: _error!);

    final qrEnabled = ref.watch(_qrEnabledProvider);

    return Scaffold(
      backgroundColor: slateBg,
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _MenuTab(
            tableId: widget.tableId,
            branchId: widget.branchId,
            qrEnabled: qrEnabled,
            onOrderPlaced: _onOrderPlaced,
          ),
          const _OrderTrackingTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: slateCard,
        indicatorColor: copperAccent.withValues(alpha: 0.2),
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu, color: copperAccent),
            label: 'Menu',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: copperAccent),
            label: 'My Orders',
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final session = ref.watch(_sessionProvider);
    return AppBar(
      backgroundColor: slateBg,
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [copperAccent, roseGold]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.restaurant, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DINE OPS',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2)),
              if (session != null)
                Text(
                  session['tableLabel'] ?? '',
                  style: const TextStyle(color: textSecondary, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _onOrderPlaced(Map<String, dynamic> order) {
    final session = ref.read(_sessionProvider);
    if (session != null) {
      _dio.patch('/sessions/${session['_id']}/refresh',
          options: Options(headers: {'Idempotency-Key': 'refresh-post-order-${order['_id']}'}));
    }
    ref.read(_qrOrdersProvider.notifier).update((list) => [order, ...list]);
    setState(() => _tabIndex = 1);
  }
}

// ── Menu Tab ──────────────────────────────────────────────────────────────────

class _MenuTab extends ConsumerStatefulWidget {
  final String tableId;
  final String branchId;
  final bool qrEnabled;
  final void Function(Map<String, dynamic>) onOrderPlaced;

  const _MenuTab({
    required this.tableId,
    required this.branchId,
    required this.qrEnabled,
    required this.onOrderPlaced,
  });

  @override
  ConsumerState<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends ConsumerState<_MenuTab> {
  final Map<String, int> _cart = {};
  bool _placing = false;

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuProvider(widget.branchId));

    return menuAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: crimson))),
      data: (items) {
        final available = items.where((i) => i.isAvailable).toList();
        final categories = available.map((i) => i.category).toSet().toList()..sort();
        final cartTotal = _cart.entries.fold<double>(0, (sum, e) {
          final item = available.firstWhere((i) => i.id == e.key, orElse: () => available.first);
          return sum + item.basePrice * e.value;
        });

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                if (!widget.qrEnabled)
                  const _InfoBanner(
                    icon: Icons.info_outline,
                    color: amber,
                    message: 'Online ordering is currently unavailable. Browse the menu below.',
                  ),
                ...categories.map((cat) {
                  final catItems = available.where((i) => i.category == cat).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(cat,
                            style: const TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                      ),
                      ...catItems.map((item) => _QrMenuTile(
                            item: item,
                            qty: _cart[item.id] ?? 0,
                            enabled: widget.qrEnabled,
                            onAdd: () => setState(() => _cart[item.id] = (_cart[item.id] ?? 0) + 1),
                            onRemove: () => setState(() {
                              final q = (_cart[item.id] ?? 0) - 1;
                              if (q <= 0) {
                                _cart.remove(item.id);
                              } else {
                                _cart[item.id] = q;
                              }
                            }),
                          )),
                    ],
                  );
                }),
              ],
            ),
            if (_cart.isNotEmpty && widget.qrEnabled)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _PlaceOrderButton(
                  total: cartTotal,
                  loading: _placing,
                  onTap: () => _placeOrder(available),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _placeOrder(List<MenuItemModel> menuItems) async {
    if (_cart.isEmpty || _placing) return;
    setState(() => _placing = true);

    final session = ref.read(_sessionProvider);
    final items = _cart.entries.map((e) {
      final item = menuItems.firstWhere((m) => m.id == e.key);
      return {'itemId': item.id, 'name': item.name, 'quantity': e.value, 'unitPrice': item.basePrice};
    }).toList();

    try {
      final idempotencyKey = const Uuid().v4();
      final dio = createDioClient(null);
      // Customer flow hits the unauthenticated /orders/public endpoint.
      // Backend takes branchId and tableId from the session, not the body,
      // so a tampered request can't post to a different table.
      final res = await dio.post(
        '/orders/public',
        data: {
          'tableId': widget.tableId,
          'tableLabel': session?['tableLabel'] ?? 'Table',
          'items': items,
          'sessionId': session?['_id'],
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      setState(() => _cart.clear());
      widget.onOrderPlaced(Map<String, dynamic>.from(res.data));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeApiError(e)),
          backgroundColor: crimson,
        ),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }
}

// ── Order Tracking Tab ────────────────────────────────────────────────────────

class _OrderTrackingTab extends ConsumerWidget {
  const _OrderTrackingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(_qrOrdersProvider);

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 56, color: textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('No orders yet',
                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Place an order from the menu',
                style: TextStyle(color: textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (_, i) => _QrOrderCard(order: orders[i]),
    );
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _QrMenuTile extends StatelessWidget {
  final MenuItemModel item;
  final int qty;
  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _QrMenuTile({
    required this.item,
    required this.qty,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: slateCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: qty > 0 ? copperAccent.withValues(alpha: 0.4) : dividerColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  if (item.description != null)
                    Text(item.description!,
                        style: const TextStyle(color: textSecondary, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('₹${item.basePrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: copperAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            if (!enabled)
              const SizedBox.shrink()
            else if (qty == 0)
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: copperAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add, color: copperAccent, size: 18),
                ),
              )
            else
              Row(
                children: [
                  GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: slateSurface,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.remove, color: textSecondary, size: 18),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('$qty',
                        style: const TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                  GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: copperAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.add, color: copperAccent, size: 18),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ).animate().fadeIn(duration: 250.ms);
}

class _QrOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _QrOrderCard({required this.order});

  static const _statusColors = {
    'created': textSecondary,
    'confirmed': amber,
    'preparing': copperAccent,
    'ready': emerald,
    'served': emerald,
    'billed': roseGold,
    'paid': emerald,
    'closed': textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'created';
    final color = _statusColors[status] ?? textSecondary;
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order #${(order['_id'] as String? ?? '').substring(0, 8)}',
                  style: const TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text('${item['quantity']}×',
                        style: const TextStyle(
                            color: copperAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(item['name'] ?? '',
                          style: const TextStyle(color: textPrimary, fontSize: 12)),
                    ),
                    Text(
                      '₹${((item['unitPrice'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}',
                      style: const TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              )),
          const Divider(color: dividerColor, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(color: textSecondary, fontSize: 12)),
              Text(
                '₹${(order['total'] ?? 0).toStringAsFixed(2)}',
                style: const TextStyle(
                    color: copperAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (status == 'ready') ...[
            const SizedBox(height: 10),
            const _InfoBanner(
              icon: Icons.check_circle_outline,
              color: emerald,
              message: 'Your order is ready! A waiter will serve you shortly.',
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _PlaceOrderButton extends StatelessWidget {
  final double total;
  final bool loading;
  final VoidCallback onTap;

  const _PlaceOrderButton({
    required this.total,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [copperAccent, copperLight]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: copperAccent.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Text('Place Order',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              if (loading)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
              else
                Text('₹${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ).animate().slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOut);
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _InfoBanner({required this.icon, required this.color, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style: TextStyle(color: color, fontSize: 12))),
          ],
        ),
      );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: slateBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: copperAccent, strokeWidth: 2),
              SizedBox(height: 16),
              Text('Loading your table...',
                  style: TextStyle(color: textSecondary, fontSize: 13)),
            ],
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: slateBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: crimson, size: 48),
                const SizedBox(height: 16),
                const Text('Something went wrong',
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(error,
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
}
