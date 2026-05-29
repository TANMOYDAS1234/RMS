// ─── Manager: Operations Tab ──────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_theme.dart';
import '../../core/services/websocket_service.dart';
import '../../core/utils/api_error.dart';
import '../../core/utils/idempotency.dart';
import '../../data/api/manager_api.dart';
import '../../domain/entities/order_entity.dart';
import '../state/order_providers.dart';
import '../widgets/status_chip.dart';

/// Ticks every 60s so widgets reading elapsed-minutes refresh
/// without needing the underlying data to change.
final _nowTickerProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  await for (final _ in Stream.periodic(const Duration(seconds: 60))) {
    yield DateTime.now();
  }
});

// ── Provider ──────────────────────────────────────────────────────────────────
final _operationsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
    (ref) => ref.watch(managerApiProvider).operations());

// ── Screen ────────────────────────────────────────────────────────────────────
class ManagerOperationsTab extends ConsumerWidget {
  const ManagerOperationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opsAsync = ref.watch(_operationsProvider);
    final liveOrders = ref.watch(liveOrdersProvider);
    final wsState = ref.watch(webSocketServiceProvider.select((s) => s.state));

    // Auto-invalidate when the server pushes an order change.
    ref.listen(wsEventsProvider, (_, next) {
      next.whenData((evt) {
        if (evt.event == 'order:updated' ||
            evt.event == 'order:created' ||
            evt.event == 'table:updated') {
          ref.invalidate(_operationsProvider);
        }
      });
    });

    return RefreshIndicator(
      color: copperAccent,
      backgroundColor: slateCard,
      onRefresh: () async => ref.invalidate(_operationsProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── WS status + refresh ──────────────────────────────────────────
          Row(children: [
            _WsChip(state: wsState),
            const Spacer(),
            GestureDetector(
              onTap: () {
                ref.invalidate(_operationsProvider);
                ref.read(liveOrdersProvider.notifier).refresh();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: slateSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: dividerColor),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.refresh, color: copperAccent, size: 14),
                  SizedBox(width: 5),
                  Text('Refresh', style: TextStyle(color: copperAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          // ── Metrics from server ──────────────────────────────────────────
          opsAsync.when(
            loading: () => const _MetricsSkeleton(),
            error: (e, _) => _ErrorBanner('$e'),
            data: (ops) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _MetricsGrid(ops: ops),
              const SizedBox(height: 16),
              if ((ops['delayedOrders'] as List? ?? []).isNotEmpty) ...[
                _DelayedOrdersBanner(
                  delayed: List<Map<String, dynamic>>.from(ops['delayedOrders']),
                  onForceClose: (id) => _forceClose(context, ref, id),
                ),
                const SizedBox(height: 16),
              ],
              _PipelineRow(pipeline: Map<String, dynamic>.from(ops['pipeline'] ?? {})),
              const SizedBox(height: 16),
              _RevenueRow(ops: ops),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Live orders list ─────────────────────────────────────────────
          Row(children: [
            const Text('Live Orders',
                style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: copperAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${liveOrders.length}',
                  style: const TextStyle(color: copperAccent, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),

          if (liveOrders.isEmpty)
            _EmptyOrders()
          else
            ...liveOrders.map((o) => _LiveOrderCard(
                  order: o,
                  onOverride: (status) => _overrideStatus(context, ref, o, status),
                  onForceClose: () => _forceClose(context, ref, o.id),
                )),
        ],
      ),
    );
  }

  Future<void> _forceClose(BuildContext context, WidgetRef ref, String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: slateCard,
        title: const Text('Force Close Order?', style: TextStyle(color: textPrimary)),
        content: const Text('This will immediately close the order. Action is logged.',
            style: TextStyle(color: textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Force Close', style: TextStyle(color: crimson, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(managerApiProvider).forceCloseOrder(
            orderId,
            idempotencyKey: newIdempotencyKey('force-close-$orderId'),
          );
      ref.invalidate(_operationsProvider);
      ref.read(liveOrdersProvider.notifier).refresh();
      if (context.mounted) _snack(context, 'Order force-closed', crimson);
    } catch (e) {
      if (context.mounted) _snack(context, describeApiError(e), crimson);
    }
  }

  Future<void> _overrideStatus(
      BuildContext context, WidgetRef ref, OrderEntity order, OrderStatus status) async {
    try {
      await ref.read(managerApiProvider).overrideOrderStatus(
            order.id,
            status.statusName,
            idempotencyKey:
                newIdempotencyKey('override-${order.id}-${status.statusName}'),
            expectedVersion: order.version,
          );
      ref.read(liveOrdersProvider.notifier).refresh();
      ref.invalidate(_operationsProvider);
      if (context.mounted) _snack(context, 'Status overridden → ${status.label}', emerald);
    } catch (e) {
      if (context.mounted) _snack(context, describeApiError(e), crimson);
    }
  }
}

// ── Metrics grid ──────────────────────────────────────────────────────────────
class _MetricsGrid extends StatelessWidget {
  final Map<String, dynamic> ops;
  const _MetricsGrid({required this.ops});

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.7,
        children: [
          _MetricCard('Active Orders', '${ops['activeOrders'] ?? 0}',
              Icons.receipt_outlined, copperAccent),
          _MetricCard('Occupied Tables',
              '${ops['occupiedTables'] ?? 0}/${ops['totalTables'] ?? 0}',
              Icons.table_restaurant_outlined, roseGold),
          _MetricCard('Low Stock', '${ops['lowStockAlerts'] ?? 0}',
              Icons.warning_amber_outlined,
              (ops['lowStockAlerts'] ?? 0) > 0 ? crimson : emerald),
          _MetricCard('Unpaid Bills', '${ops['unpaidBills'] ?? 0}',
              Icons.pending_outlined, amber),
        ],
      );
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: slateCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, color: color, size: 20),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(color: textSecondary, fontSize: 10)),
          ]),
        ]),
      ).animate().fadeIn(duration: 300.ms);
}

// ── Pipeline row ──────────────────────────────────────────────────────────────
class _PipelineRow extends StatelessWidget {
  final Map<String, dynamic> pipeline;
  const _PipelineRow({required this.pipeline});

  static const _stages = ['created', 'confirmed', 'preparing', 'ready', 'served'];
  static const _colors = {
    'created': textSecondary,
    'confirmed': amber,
    'preparing': copperAccent,
    'ready': emerald,
    'served': roseGold,
  };

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Pipeline',
              style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: _stages.map((stage) {
              final count = pipeline[stage] as int? ?? 0;
              final color = _colors[stage] ?? textSecondary;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: slateCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: count > 0 ? color.withValues(alpha: 0.4) : dividerColor,
                    ),
                  ),
                  child: Column(children: [
                    Text('$count',
                        style: TextStyle(
                            color: count > 0 ? color : textSecondary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(stage,
                        style: const TextStyle(color: textSecondary, fontSize: 8),
                        textAlign: TextAlign.center),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
      );
}

// ── Revenue row ───────────────────────────────────────────────────────────────
class _RevenueRow extends StatelessWidget {
  final Map<String, dynamic> ops;
  const _RevenueRow({required this.ops});

  @override
  Widget build(BuildContext context) {
    final rev = ops['dailyRevenue'] as Map<String, dynamic>? ?? {};
    final total = (rev['total'] as num? ?? 0).toDouble();
    final count = rev['count'] as int? ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: emerald.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: emerald.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.attach_money, color: emerald, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Today's Revenue",
              style: TextStyle(color: textSecondary, fontSize: 11)),
          Text('₹${total.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: emerald, fontSize: 20, fontWeight: FontWeight.w800)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('Bills Paid', style: TextStyle(color: textSecondary, fontSize: 11)),
          Text('$count',
              style: const TextStyle(
                  color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

// ── Delayed orders banner ─────────────────────────────────────────────────────
class _DelayedOrdersBanner extends StatelessWidget {
  final List<Map<String, dynamic>> delayed;
  final void Function(String id) onForceClose;
  const _DelayedOrdersBanner({required this.delayed, required this.onForceClose});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: crimson.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crimson.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.timer_off_outlined, color: crimson, size: 16),
            const SizedBox(width: 6),
            Text('${delayed.length} Delayed Order${delayed.length > 1 ? 's' : ''} (>15 min)',
                style: const TextStyle(
                    color: crimson, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          ...delayed.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const Icon(Icons.table_restaurant_outlined,
                      size: 12, color: textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${o['tableLabel']} · ${o['status']} · ${o['minutesElapsed']}m',
                      style: const TextStyle(color: textPrimary, fontSize: 12),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onForceClose(o['_id']?.toString() ?? o['id']?.toString() ?? ''),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: crimson.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: crimson.withValues(alpha: 0.3)),
                      ),
                      child: const Text('Close',
                          style: TextStyle(
                              color: crimson, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              )),
        ]),
      ).animate().fadeIn(duration: 300.ms);
}

// ── Live order card ───────────────────────────────────────────────────────────
class _LiveOrderCard extends ConsumerWidget {
  final OrderEntity order;
  final void Function(OrderStatus) onOverride;
  final VoidCallback onForceClose;
  const _LiveOrderCard({
    required this.order,
    required this.onOverride,
    required this.onForceClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(_nowTickerProvider).value ?? DateTime.now();
    final elapsed = now.difference(order.updatedAt);
    final isDelayed = elapsed.inMinutes > 15 &&
        (order.status == OrderStatus.confirmed ||
            order.status == OrderStatus.preparing);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDelayed ? crimson.withValues(alpha: 0.5) : dividerColor,
          width: isDelayed ? 1.5 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (isDelayed)
            Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(color: crimson, shape: BoxShape.circle),
            ).animate(onPlay: (c) => c.repeat())
                .fadeIn(duration: 600.ms).then().fadeOut(duration: 600.ms),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.tableLabel,
                  style: const TextStyle(
                      color: textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
              Text('${order.items.length} items · ${elapsed.inMinutes}m ago',
                  style: const TextStyle(color: textSecondary, fontSize: 11)),
            ]),
          ),
          StatusChip(status: order.status),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Text('₹${order.total.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: copperAccent, fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          // Override status
          GestureDetector(
            onTap: () => _showOverrideSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: slateSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: dividerColor),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.swap_horiz, color: textSecondary, size: 14),
                SizedBox(width: 4),
                Text('Override',
                    style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          // Force close
          GestureDetector(
            onTap: onForceClose,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: crimson.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: crimson.withValues(alpha: 0.3)),
              ),
              child: const Text('Force Close',
                  style: TextStyle(
                      color: crimson, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ]),
    ).animate().fadeIn(duration: 250.ms);
  }

  void _showOverrideSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Override Status — ${order.tableLabel}',
              style: const TextStyle(
                  color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Current: ${order.status.label}',
              style: const TextStyle(color: textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ...OrderStatus.values
              .where((s) => s != order.status && s != OrderStatus.closed)
              .map((s) => GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onOverride(s);
                    },
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: slateSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: dividerColor),
                      ),
                      child: Center(
                        child: Text('→ ${s.label}',
                            style: const TextStyle(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  )),
        ]),
      ),
    );
  }
}

// ── WS chip ───────────────────────────────────────────────────────────────────
class _WsChip extends StatelessWidget {
  final SocketState state;
  const _WsChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (state) {
      SocketState.connected    => (emerald, 'Live'),
      SocketState.connecting   => (amber, 'Connecting'),
      SocketState.disconnected => (textSecondary, 'Offline'),
      SocketState.error        => (crimson, 'Error'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle))
            .animate(onPlay: (c) => c.repeat())
            .fadeIn(duration: 800.ms).then().fadeOut(duration: 800.ms),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyOrders extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_outline,
                size: 48, color: emerald.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text('All clear!',
                style: TextStyle(
                    color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('No active orders right now',
                style: TextStyle(color: textSecondary, fontSize: 12)),
          ]),
        ),
      );
}

// ── Skeleton ──────────────────────────────────────────────────────────────────
class _MetricsSkeleton extends StatelessWidget {
  const _MetricsSkeleton();
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.7,
        children: List.generate(
          4,
          (_) => Container(
            decoration: BoxDecoration(
              color: slateCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: copperAccent, strokeWidth: 2),
            ),
          ),
        ),
      );
}

// ── Error banner ──────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: crimson.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crimson.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: crimson, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: crimson, fontSize: 12))),
        ]),
      );
}

void _snack(BuildContext context, String msg, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
  ));
}
