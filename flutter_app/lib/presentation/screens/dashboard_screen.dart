// ─── Premium Dashboard Screen ────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/config/app_config.dart';
import '../../core/config/app_theme.dart';
import '../../core/services/websocket_service.dart';
import '../../core/utils/api_error.dart';
import '../../domain/entities/order_entity.dart';
import '../state/menu_provider.dart';
import '../state/order_providers.dart';
import '../state/auth_provider.dart';
import '../widgets/order_card.dart';
import '../widgets/metrics_ribbon.dart';
import '../widgets/status_chip.dart';
import '../../domain/entities/user_entity.dart';
import '../widgets/waiter_inbox.dart';
import 'admin_profile_screen.dart';
import 'new_order_screen.dart';
import 'qr_scanner_screen.dart';

/// Lifted state for the filter chips so the list actually filters.
/// 0 = All, 1 = Urgent (READY/SERVED), 2 = Pending (CREATED/CONFIRMED/PREPARING).
final dashboardFilterProvider = StateProvider<int>((_) => 0);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(liveOrdersProvider);
    final metrics = ref.watch(dashboardMetricsProvider);
    final wsState = ref.watch(
      webSocketServiceProvider.select((s) => s.state),
    );
    final filter = ref.watch(dashboardFilterProvider);

    final filtered = switch (filter) {
      1 => orders
          .where((o) =>
              o.status == OrderStatus.ready ||
              o.status == OrderStatus.served)
          .toList(),
      2 => orders
          .where((o) =>
              o.status == OrderStatus.created ||
              o.status == OrderStatus.confirmed ||
              o.status == OrderStatus.preparing)
          .toList(),
      _ => orders,
    };

    return Scaffold(
      backgroundColor: slateBg,
      appBar: _buildAppBar(wsState),
      body: RefreshIndicator(
        color: copperAccent,
        backgroundColor: slateCard,
        onRefresh: () => ref.read(liveOrdersProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: MetricsRibbon(
                activeOrders: metrics.activeOrders,
                occupiedTables: metrics.occupiedTables,
                totalTables: metrics.totalTables,
                revenue: metrics.revenue,
              ),
            ),
            // Show the call-waiter inbox above the order list. The widget
            // renders empty when there are no open requests so it's free
            // when the dining room is quiet.
            const SliverToBoxAdapter(child: WaiterInbox()),
            SliverToBoxAdapter(
              child: _buildSectionHeader(orders, filtered),
            ),
            if (filtered.isEmpty)
              const SliverToBoxAdapter(child: _EmptyFiltered())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => OrderCard(
                      order: filtered[i],
                      onStatusTap: () =>
                          _showStatusSheet(context, ref, filtered[i]),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      // QR scan + New Order are waiter-only actions. Chef has no use for
      // QR scanning (they don't seat customers), and cashier never takes
      // orders — they only handle billing/payment for existing ones.
      // Hiding the FAB cluster for those roles cleans up the UI and
      // prevents accidental order creation by the wrong staff.
      floatingActionButton: ref.watch(authProvider).user?.role == UserRole.waiter
          ? _buildFAB(context)
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(SocketState wsState) => AppBar(
        backgroundColor: slateBg,
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [copperAccent, roseGold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.restaurant, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('DINE OPS',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                )),
          ],
        ),
        actions: [
          _WsIndicator(state: wsState),
          Consumer(
            builder: (ctx, ref, _) {
              // Watch the whole user so the avatar rebuilds when refreshUser()
              // bumps updatedAt — otherwise a successful photo upload never
              // re-renders the AppBar circle.
              final user = ref.watch(authProvider).user;
              final photoFullUrl = user?.photoUrlFor(AppConfig.baseUrl);
              final initial = (user?.name.isNotEmpty == true)
                  ? user!.name.substring(0, 1).toUpperCase()
                  : 'A';
              return PopupMenuButton(
              color: slateCard,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: copperAccent.withValues(alpha: 0.2),
                child: photoFullUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: photoFullUrl,
                          width: 30,
                          height: 30,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Text(initial,
                              style: const TextStyle(color: copperAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                          errorWidget: (_, __, ___) => Text(initial,
                              style: const TextStyle(color: copperAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      )
                    : Text(initial,
                        style: const TextStyle(color: copperAccent, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              itemBuilder: (_) => <PopupMenuEntry<dynamic>>[
                // Quick profile readout — name + role — non-clickable.
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'Staff',
                          style: const TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      Text((user?.role.name ?? '').toUpperCase(),
                          style: const TextStyle(
                              color: textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  child: const Row(children: [
                    Icon(Icons.person_outline, color: copperAccent, size: 16),
                    SizedBox(width: 8),
                    Text('My Profile', style: TextStyle(color: textPrimary)),
                  ]),
                  onTap: () {
                    // PopupMenuItem closes the menu before the onTap fires,
                    // so the Navigator.push has to be deferred a frame.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.of(ctx).push(MaterialPageRoute(
                          builder: (_) => const AdminProfileScreen()));
                    });
                  },
                ),
                PopupMenuItem(
                  child: const Row(children: [Icon(Icons.logout, color: crimson, size: 16), SizedBox(width: 8), Text('Logout', style: TextStyle(color: crimson))]),
                  onTap: () => ref.read(authProvider.notifier).logout(),
                ),
              ],
            );
            },
          ),
          const SizedBox(width: 8),
        ],
      );

  Widget _buildSectionHeader(
          List<OrderEntity> allOrders, List<OrderEntity> visible) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Row(
          children: [
            const Text(
              'Live Orders',
              style: TextStyle(
                color: textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: copperAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                visible.length == allOrders.length
                    ? '${allOrders.length}'
                    : '${visible.length}/${allOrders.length}',
                style: const TextStyle(
                    color: copperAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const Spacer(),
            const _FilterChips(),
          ],
        ),
      );

  Widget _buildFAB(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            // Unique tag — when multiple FABs are mounted (other tabs in
            // an IndexedStack), Flutter's default tag collides.
            heroTag: 'waiter_qr_scan_fab',
            backgroundColor: slateCard,
            foregroundColor: copperAccent,
            tooltip: 'Scan table QR',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QrScannerScreen()),
            ),
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'waiter_new_order_fab',
            backgroundColor: copperAccent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('New Order',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NewOrderScreen()),
            ),
          ),
        ],
      ).animate().scale(delay: 600.ms, duration: 300.ms);

  void _showStatusSheet(
      BuildContext context, WidgetRef ref, OrderEntity order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _StatusUpdateSheet(order: order, ref: ref),
    );
  }
}

// ── WebSocket connection indicator ────────────────────────────────────────────
class _WsIndicator extends StatelessWidget {
  final SocketState state;
  const _WsIndicator({required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (state) {
      SocketState.connected => (emerald, 'Live'),
      SocketState.connecting => (amber, 'Connecting'),
      SocketState.disconnected => (textSecondary, 'Offline'),
      SocketState.error => (crimson, 'Error'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 800.ms).then().fadeOut(duration: 800.ms),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Filter chips (bound to dashboardFilterProvider) ─────────────────────────
class _FilterChips extends ConsumerWidget {
  const _FilterChips();
  static const _filters = ['All', 'Urgent', 'Pending'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(dashboardFilterProvider);
    return Row(
      children: List.generate(_filters.length, (i) {
        final active = selected == i;
        return GestureDetector(
          onTap: () => ref.read(dashboardFilterProvider.notifier).state = i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: active
                  ? copperAccent.withValues(alpha: 0.2)
                  : slateSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? copperAccent : Colors.transparent,
              ),
            ),
            child: Text(
              _filters[i],
              style: TextStyle(
                color: active ? copperAccent : textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Empty state when the filter excludes every order ────────────────────────
class _EmptyFiltered extends StatelessWidget {
  const _EmptyFiltered();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inbox_outlined,
                size: 36, color: textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            const Text('No orders match this filter',
                style: TextStyle(color: textSecondary, fontSize: 12)),
          ]),
        ),
      );
}

// ── Status update bottom sheet ────────────────────────────────────────────────
class _StatusUpdateSheet extends StatelessWidget {
  final OrderEntity order;
  final WidgetRef ref;

  const _StatusUpdateSheet({required this.order, required this.ref});

  @override
  Widget build(BuildContext context) {
    final nextStatuses = OrderStatus.values
        .where((s) => order.status.canTransitionTo(s))
        .toList();
    // Amend allowed before the kitchen starts (matches the backend rule
    // in OrdersService.amendItems).
    final canAmend = order.status == OrderStatus.created ||
        order.status == OrderStatus.confirmed;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Update Order #${order.id}',
                style: const TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            order.tableLabel,
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          if (canAmend) ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Amend items'),
              style: OutlinedButton.styleFrom(
                foregroundColor: copperAccent,
                side: const BorderSide(color: copperAccent),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: slateCard,
                  shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => _AmendItemsSheet(order: order),
                );
              },
            ),
            const SizedBox(height: 14),
          ],
          if (nextStatuses.isEmpty)
            const Text('No further transitions available.',
                style: TextStyle(color: textSecondary))
          else
            ...nextStatuses.map(
              (s) => _ActionButton(
                status: s,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(liveOrdersProvider.notifier).updateStatus(order.id, s);
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Amend items bottom sheet ───────────────────────────────────────────────
class _AmendItemsSheet extends ConsumerStatefulWidget {
  final OrderEntity order;
  const _AmendItemsSheet({required this.order});
  @override
  ConsumerState<_AmendItemsSheet> createState() => _AmendItemsSheetState();
}

class _AmendItemsSheetState extends ConsumerState<_AmendItemsSheet> {
  late final Map<String, int> _cart;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Seed the cart from the current order. Item ids should match menu ids
    // because that's how the order was created.
    _cart = {
      for (final i in widget.order.items) i.id: i.quantity,
    };
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_cart.values.every((q) => q == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Order must have at least one item.'),
        backgroundColor: amber,
      ));
      return;
    }
    final branchId = ref.read(authProvider).user?.branchId;
    final menu = ref.read(menuProvider(branchId)).value ?? [];
    // Build the items payload from the cart. Prefer the menu's current
    // price (could have changed since the order was created); fall back
    // to the existing line item's unitPrice if the menu no longer
    // contains the id.
    final items = _cart.entries
        .where((e) => e.value > 0)
        .map((e) {
      final menuItem = menu.where((m) => m.id == e.key).cast<dynamic>().firstOrNull;
      final orderItem = widget.order.items.where((i) => i.id == e.key).cast<dynamic>().firstOrNull;
      final name = menuItem?.name ?? orderItem?.name ?? 'Item';
      final price = menuItem?.basePrice ?? orderItem?.unitPrice ?? 0;
      return {
        'itemId': e.key,
        'name': name,
        'quantity': e.value,
        'unitPrice': price,
      };
    }).toList();

    setState(() => _busy = true);
    try {
      await ref.read(liveOrdersProvider.notifier).amendItems(
            orderId: widget.order.id,
            items: items,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Order amended'),
          backgroundColor: emerald,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(describeApiError(e)),
          backgroundColor: crimson,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.order.items.toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: textSecondary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 14),
        Text('Amend items — ${widget.order.tableLabel}',
            style: const TextStyle(
                color: textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
            'Adjust quantities; set to 0 to remove. New items must be added via "New Order" — to add a brand-new dish, cancel this and place a separate order.',
            style: TextStyle(color: textSecondary, fontSize: 11)),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final item in entries)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: slateSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                                style: const TextStyle(
                                    color: textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text('₹${item.unitPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: copperAccent, fontSize: 11)),
                          ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove, color: textSecondary, size: 18),
                      onPressed: () => setState(() {
                        final q = (_cart[item.id] ?? 0) - 1;
                        if (q <= 0) {
                          _cart.remove(item.id);
                        } else {
                          _cart[item.id] = q;
                        }
                      }),
                    ),
                    Text('${_cart[item.id] ?? 0}',
                        style: const TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    IconButton(
                      icon: const Icon(Icons.add, color: copperAccent, size: 18),
                      onPressed: () => setState(() {
                        _cart[item.id] = (_cart[item.id] ?? 0) + 1;
                      }),
                    ),
                  ]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_outlined, size: 16),
            label: const Text('Save changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: copperAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800),
            ),
            onPressed: _busy ? null : _save,
          ),
        ),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final OrderStatus status;
  final VoidCallback onTap;

  const _ActionButton({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [copperAccent, copperLight],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              'Mark as ${status.label}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
}
