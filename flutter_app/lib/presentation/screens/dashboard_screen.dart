// ─── Premium Dashboard Screen ────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/config/app_theme.dart';
import '../../core/services/websocket_service.dart';
import '../../domain/entities/order_entity.dart';
import '../state/order_providers.dart';
import '../state/auth_provider.dart';
import '../widgets/order_card.dart';
import '../widgets/metrics_ribbon.dart';
import '../widgets/status_chip.dart';
import 'new_order_screen.dart';

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
      floatingActionButton: _buildFAB(context),
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
            builder: (ctx, ref, _) => PopupMenuButton(
              color: slateCard,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: copperAccent.withValues(alpha: 0.2),
                child: Text(
                  ref.watch(authProvider).user?.name.substring(0, 1).toUpperCase() ?? 'A',
                  style: const TextStyle(color: copperAccent, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              itemBuilder: (_) => [
                PopupMenuItem(
                  child: const Row(children: [Icon(Icons.logout, color: crimson, size: 16), SizedBox(width: 8), Text('Logout', style: TextStyle(color: crimson))]),
                  onTap: () => ref.read(authProvider.notifier).logout(),
                ),
              ],
            ),
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

  Widget _buildFAB(BuildContext context) => FloatingActionButton.extended(
        backgroundColor: copperAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Order', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewOrderScreen())),
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
