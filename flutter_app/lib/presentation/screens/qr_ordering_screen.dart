// ─── QR Customer Ordering Screen (Flutter Web PWA) ───────────────────────────
// Entry: https://yourdomain.com/t/{tableId}?branch={branchId}
// Handles: session resume, feature-flag check, menu browse, order placement, tracking

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/app_theme.dart';
import '../../core/utils/web_window.dart';
import '../../core/utils/razorpay_checkout.dart';
import '../../core/utils/idempotency.dart';
import '../../core/config/system_config_provider.dart';
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
      //
      //    Multi-party flow:
      //    - First call goes without partySize.
      //    - If the device is new to the table the backend responds with
      //      { needsPartySize: true, capacity, occupied, remaining, ... }.
      //      We prompt the customer for their party size, then retry the
      //      scan with that value. Returning customers (deviceId already
      //      participates) skip the prompt — the backend returns their
      //      session straight away.
      Map<String, dynamic> session = await _scanSession(partySize: null);
      if (session['needsPartySize'] == true) {
        final remaining = (session['remaining'] as num?)?.toInt() ?? 0;
        if (remaining <= 0) {
          throw _FullTableError(
            tableLabel: session['tableLabel']?.toString() ?? 'this table',
          );
        }
        final picked = await _askPartySize(remaining);
        if (picked == null) {
          // User backed out — leave the screen in error state with a hint
          // that they can pull-to-refresh.
          throw _CancelledError();
        }
        session = await _scanSession(partySize: picked);
      }
      ref.read(_sessionProvider.notifier).state =
          Map<String, dynamic>.from(session);

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
      // The multi-party flow throws typed errors for the cases where a
      // generic "request failed" message would be wrong. Map them to
      // their own copy; everything else flows through describeApiError.
      String msg;
      if (e is _FullTableError) {
        msg = '${e.tableLabel} is full right now. Please ask a server to seat you at another table.';
      } else if (e is _CancelledError) {
        msg = 'Tap refresh to choose your party size and start ordering.';
      } else {
        msg = describeApiError(e);
      }
      setState(() => _error = msg);
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

  /// Header subtitle for the QR ordering screen — fits the multi-party
  /// model: "Table 5 · Party A · 2 ppl". Falls back to just the table
  /// label when partyLabel is missing (legacy sessions).
  String _headerSubtitle(Map<String, dynamic> session) {
    final table = session['tableLabel']?.toString() ?? '';
    final party = session['partyLabel']?.toString() ?? '';
    final size = (session['partySize'] as num?)?.toInt() ?? 0;
    final parts = <String>[
      if (table.isNotEmpty) table,
      if (party.isNotEmpty) 'Party $party',
      if (size > 0) '$size ${size == 1 ? 'person' : 'ppl'}',
    ];
    return parts.join(' · ');
  }

  /// Round-trips POST /sessions/scan and returns the raw response map —
  /// either a session document or a `{ needsPartySize: true, ... }`
  /// envelope. Idempotency key is stable per (device, table, partySize)
  /// so a refresh doesn't spawn a parallel session.
  Future<Map<String, dynamic>> _scanSession({required int? partySize}) async {
    final res = await _dio.post(
      '/sessions/scan',
      data: {
        'tableId': widget.tableId,
        'branchId': widget.branchId,
        'deviceId': _deviceId,
        if (partySize != null) 'partySize': partySize,
      },
      options: Options(headers: {
        'Idempotency-Key': 'scan-${widget.tableId}-$_deviceId-${partySize ?? 'probe'}',
      }),
    );
    return Map<String, dynamic>.from(res.data);
  }

  /// Bottom-sheet prompt: "How many of you are seated?". Caps the picker
  /// at the table's remaining capacity so the customer can't pick more
  /// than what's free (the backend re-checks regardless).
  Future<int?> _askPartySize(int remaining) async {
    int selected = 1;
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Icon(Icons.groups_2_outlined, color: copperAccent, size: 32),
            const SizedBox(height: 10),
            const Text('How many of you are seated?',
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              remaining == 1
                  ? '1 seat free at this table.'
                  : '$remaining seats free at this table.',
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            // Stepper row — minus / count / plus.
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _StepperButton(
                icon: Icons.remove,
                onTap: selected > 1 ? () => setSt(() => selected--) : null,
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 60,
                child: Text('$selected',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 24),
              _StepperButton(
                icon: Icons.add,
                onTap: selected < remaining ? () => setSt(() => selected++) : null,
              ),
            ]),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, selected),
                style: ElevatedButton.styleFrom(
                  backgroundColor: copperAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1),
                ),
                child: const Text('CONTINUE'),
              ),
            ),
          ]),
        ),
      ),
    );
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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: false,
      appBar: _buildAppBar(),
      body: Stack(children: [
        const Positioned.fill(child: _AmbientBackdrop()),
        // Responsive shell: on phones the menu fills the screen; on
        // tablets/desktop we cap it at 640 px and center, so the menu
        // doesn't read as a stretched single column on a 1080 px window.
        // The backdrop above still fills edge-to-edge so the orbs feel
        // ambient, not clipped.
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: IndexedStack(
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
          ),
        ),
      ]),
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
                  _headerSubtitle(session),
                  style: const TextStyle(color: textSecondary, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
      actions: [
        if (session != null)
          // One-tap = instantly notify a waiter; long-press = add a note.
          // The bell pulses copper while a call is pending to remind the
          // customer help is on the way (resets when a waiter resolves).
          GestureDetector(
            onLongPress: () => _callWaiterWithNote(session),
            child: IconButton(
              tooltip: 'Call a waiter (long-press to add note)',
              icon: const Icon(Icons.notifications_active_outlined,
                  color: copperAccent),
              onPressed: () => _callWaiter(session),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(
                    begin: 0.95,
                    end: 1.08,
                    duration: 900.ms,
                    curve: Curves.easeInOut),
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  /// Long-press path on the bell — surfaces an optional note field for
  /// customers who want to add context ("the bill, please"). Delegates
  /// to _callWaiter so the network code lives in one place.
  Future<void> _callWaiterWithNote(Map<String, dynamic> session) async {
    final reasonCtrl = TextEditingController();
    final reason = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 18, 24, MediaQuery.of(ctx).viewInsets.bottom + 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: textSecondary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Add a quick note',
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Optional — the waiter will see this with the call.',
              style: TextStyle(color: textSecondary, fontSize: 12)),
          const SizedBox(height: 14),
          TextField(
            controller: reasonCtrl,
            autofocus: true,
            maxLines: 2,
            style: const TextStyle(color: textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'e.g. extra napkins, water, the bill…',
              hintStyle: const TextStyle(color: textSecondary, fontSize: 12),
              filled: true,
              fillColor: slateSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: copperAccent),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Send'),
              style: ElevatedButton.styleFrom(
                backgroundColor: copperAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () =>
                  Navigator.pop(ctx, reasonCtrl.text.trim()),
            ),
          ),
        ]),
      ),
    );
    reasonCtrl.dispose();
    if (reason == null) return;
    await _callWaiter(session, reason: reason);
  }

  /// Call-waiter — now a one-tap action.
  ///
  /// Tap the AppBar bell → fires `POST /sessions/:id/call-waiter` with no
  /// reason → waiter team gets a push instantly (backend fan-out via FCM
  /// + WebSocket to every waiter in the branch). Until one waiter
  /// resolves the help request, the bell pulses crimson so the customer
  /// knows the call is still pending.
  ///
  /// Optional note: customers who do want to add context (e.g. "the
  /// bill, please") can long-press the bell to open a quick-note sheet.
  Future<void> _callWaiter(Map<String, dynamic> session,
      {String? reason}) async {
    try {
      await _dio.post(
        '/sessions/${session['_id']}/call-waiter',
        data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
        options: Options(headers: {
          'Idempotency-Key': _uuid.v4(),
        }),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: emerald,
        duration: const Duration(seconds: 2),
        content: Row(children: const [
          Icon(Icons.check_circle, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('Waiter notified — on the way!')),
        ]),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: crimson,
        content: Text(describeApiError(e)),
      ));
    }
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
                // Track a running index across categories so the stagger
                // delay continues smoothly section-to-section rather than
                // restarting at every category header.
                ...(() {
                  int idx = 0;
                  return categories.map((cat) {
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
                        )
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideX(begin: -0.2, end: 0, duration: 300.ms),
                        ...catItems.map((item) {
                          final delay = (idx++ * 40).ms;
                          return _QrMenuTile(
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
                          )
                              .animate()
                              .fadeIn(delay: delay, duration: 400.ms)
                              // Y-axis rotate on entrance feels like the
                              // tile is flipping off a stack — paired
                              // with the slide it reads as 3D depth.
                              .slideY(
                                  begin: 0.25,
                                  end: 0,
                                  delay: delay,
                                  duration: 400.ms,
                                  curve: Curves.easeOutCubic)
                              .rotate(
                                  begin: -0.04,
                                  end: 0,
                                  delay: delay,
                                  duration: 500.ms,
                                  curve: Curves.easeOutBack)
                              .scaleXY(
                                  begin: 0.92,
                                  end: 1.0,
                                  delay: delay,
                                  duration: 400.ms,
                                  curve: Curves.easeOutBack);
                        }),
                      ],
                    );
                  });
                })(),
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

    // Tally what's owed so the Pay Now button can show the running total.
    // Bills haven't necessarily been generated yet, so we sum the orders
    // themselves and exclude anything already paid or closed.
    double outstanding = 0;
    for (final o in orders) {
      final st = (o['status'] as String?) ?? '';
      if (st == 'paid' || st == 'closed') continue;
      outstanding += ((o['total'] as num?) ?? 0).toDouble();
    }

    return Column(children: [
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (_, i) => _QrOrderCard(order: orders[i]),
        ),
      ),
      // Sticky Pay Now bar — only shown on web (Razorpay Checkout JS is
      // web-only) and only when there's a balance to pay. Also requires
      // the server to expose razorpayWebEnabled (both KEY_ID + KEY_SECRET
      // configured) — otherwise the button would 400 with the
      // env-var-missing message.
      if (kIsWeb && outstanding > 0)
        Consumer(builder: (ctx, ref, _) {
          final cfg = ref.watch(systemConfigProvider);
          final ready = cfg.maybeWhen(
            data: (c) => c.razorpayWebEnabled,
            orElse: () => false,
          );
          if (!ready) return const SizedBox.shrink();
          return _PayNowBar(outstanding: outstanding);
        }),
    ]);
  }
}

/// Sticky bottom bar with "Pay Now" CTA, only rendered on the customer
/// web build. Opens Razorpay Checkout JS via the conditional facade and
/// hits POST /sessions/:id/pay/init + /pay/verify on success.
class _PayNowBar extends ConsumerStatefulWidget {
  final double outstanding;
  const _PayNowBar({required this.outstanding});

  @override
  ConsumerState<_PayNowBar> createState() => _PayNowBarState();
}

class _PayNowBarState extends ConsumerState<_PayNowBar> {
  bool _busy = false;

  Future<void> _payNow() async {
    if (_busy) return;
    final session = ref.read(_sessionProvider);
    if (session == null) return;
    final sessionId = (session['_id'] ?? session['id'])?.toString() ?? '';
    if (sessionId.isEmpty) return;
    setState(() => _busy = true);
    final dio = createDioClient(null);
    // One stable Idempotency-Key per attempt covers BOTH the init and
    // verify calls. If the user mashes Pay Now or the network drops mid-
    // way, the same key returns the same Razorpay Order and the same
    // "session closed as paid" result instead of creating a second
    // Razorpay Order or double-marking the session.
    final initKey = newIdempotencyKey('pay-init-$sessionId');
    final verifyKey = newIdempotencyKey('pay-verify-$sessionId');
    try {
      // 1) Init — backend creates a Razorpay Order for the running total.
      final init = await dio.post(
        '/sessions/$sessionId/pay/init',
        options: Options(headers: {'Idempotency-Key': initKey}),
      );
      final data = Map<String, dynamic>.from(init.data);
      // 2) Open Razorpay Checkout. On web this hits the JS bridge; on
      // mobile the stub returns an error and we surface it.
      final result = await openRazorpayCheckout(
        keyId: data['keyId'] ?? '',
        razorpayOrderId: data['razorpayOrderId'] ?? '',
        amountPaise: (data['amount'] as num?)?.toInt() ?? 0,
        name: 'DINE OPS',
        description: 'Table ${data['tableLabel'] ?? ''}',
      );
      if (!result.success) {
        if (mounted && result.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: crimson,
            content: Text(result.error!),
          ));
        }
        return;
      }
      // 3) Verify on the backend — HMAC + close session as paid.
      await dio.post(
        '/sessions/$sessionId/pay/verify',
        data: {
          'razorpayOrderId': result.razorpayOrderId,
          'razorpayPaymentId': result.razorpayPaymentId,
          'razorpaySignature': result.razorpaySignature,
        },
        options: Options(headers: {'Idempotency-Key': verifyKey}),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: emerald,
        content: const Text('Payment received — thank you!'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: crimson,
        content: Text(describeApiError(e)),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: slateCard,
          border: Border(top: BorderSide(color: dividerColor)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Outstanding',
                  style: TextStyle(color: textSecondary, fontSize: 11)),
              Text('₹${widget.outstanding.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: copperAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: _busy ? null : _payNow,
            icon: _busy
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.lock_outline, size: 16),
            label: Text(_busy ? 'Opening…' : 'Pay Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: copperAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
          ),
        ]),
      ),
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
                  Row(children: [
                    Text('₹${item.basePrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: copperAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    // 3D / AR preview chip — only shown on web (the QR
                    // ordering page is web-only anyway, but the guard
                    // keeps the staff app neutral). For the demo, every
                    // item uses /models/pizza.glb; once items have real
                    // GLBs uploaded, this will use item.glbUrl.
                    if (kIsWeb) ...[
                      const SizedBox(width: 8),
                      _ArChip(itemName: item.name),
                    ],
                  ]),
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

/// A compact "3D" chip rendered next to the menu tile's price.
///
/// Opens the static <model-viewer> page (`/ar.html`) in a new tab.
/// On Android the page surfaces a "View in your space" button that
/// hands off to Scene Viewer for true AR. On iOS it falls back to
/// drag-to-rotate 3D (Quick Look needs USDZ — we only have GLB for
/// the demo). Only rendered on web; on mobile this is unreachable.
class _ArChip extends StatelessWidget {
  final String itemName;
  const _ArChip({required this.itemName});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Demo: every item uses the pizza GLB. Real items will use
        // /api/menu/<id>/glb once the upload flow is wired in.
        final encoded = Uri.encodeComponent(itemName);
        openInNewTab('/ar.html?model=/models/pizza.glb&name=$encoded');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [copperAccent.withValues(alpha: 0.25), roseGold.withValues(alpha: 0.18)],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: copperAccent.withValues(alpha: 0.5), width: 0.6),
          boxShadow: [
            BoxShadow(
              color: copperAccent.withValues(alpha: 0.45),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.view_in_ar, size: 11, color: copperAccent),
          SizedBox(width: 4),
          Text('3D',
              style: TextStyle(
                  color: copperAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
        ]),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 600.ms)
          .then()
          .tint(
              color: roseGold.withValues(alpha: 0.4),
              duration: 1200.ms,
              curve: Curves.easeInOut),
    );
  }
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
                  // /sessions/:id/bill serialises the order id as `id`,
                  // not `_id`. Accept either, and never call substring on
                  // a string shorter than the slice length — which was
                  // the actual cause of "My Orders" going gray right
                  // after a successful order placement.
                  () {
                    final raw = (order['id'] ?? order['_id'] ?? '').toString();
                    return raw.isEmpty
                        ? 'Order'
                        : 'Order #${raw.substring(0, raw.length < 8 ? raw.length : 8)}';
                  }(),
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

/// Thrown internally when the QR-scan flow needs to short-circuit init
/// because the table has no free seats. Caught one frame later by the
/// parent's try/catch and routed to the friendly "ask a server" copy.
class _FullTableError implements Exception {
  final String tableLabel;
  _FullTableError({required this.tableLabel});
}

/// Customer dismissed the party-size picker. Init bails and the user
/// sees a "tap refresh to start over" hint.
class _CancelledError implements Exception {}

/// Soft animated copper-glow backdrop. Two radial gradients orbit the
/// canvas at different periods so the surface feels alive without ever
/// distracting from the menu. CompositingLayer-friendly: just two
/// containers, no per-frame allocations.
class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF120A06), Color(0xFF0A0604)],
        ),
      ),
      child: Stack(children: [
        Positioned(
          top: -120, left: -80,
          child: Container(
            width: 320, height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                copperAccent.withValues(alpha: 0.30),
                copperAccent.withValues(alpha: 0.0),
              ]),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveX(begin: 0, end: 30, duration: 5500.ms, curve: Curves.easeInOut)
              .moveY(begin: 0, end: 20, duration: 5500.ms, curve: Curves.easeInOut),
        ),
        Positioned(
          bottom: -80, right: -60,
          child: Container(
            width: 260, height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                roseGold.withValues(alpha: 0.22),
                roseGold.withValues(alpha: 0.0),
              ]),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveX(begin: 0, end: -25, duration: 6500.ms, curve: Curves.easeInOut)
              .moveY(begin: 0, end: -15, duration: 6500.ms, curve: Curves.easeInOut),
        ),
      ]),
    );
  }
}

/// Round copper stepper button used by the party-size picker. Disabled
/// state fades out and ignores taps.
class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1.0 : 0.35,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: copperAccent.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
                color: copperAccent.withValues(alpha: 0.6), width: 1.2),
          ),
          child: Icon(icon, color: copperAccent, size: 26),
        ),
      ),
    );
  }
}
