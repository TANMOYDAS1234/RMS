// ─── Kitchen Display Screen (Phase 4a) ──────────────────────────────────────
//
// Real KDS: chefs can advance the state machine, track per-item progress,
// flag items unavailable, and see overdue tickets in red. Backed by the
// existing /orders/:id/status endpoint (state-machine + optimistic lock
// already enforced server-side) and /orders/:id/items/:itemId/progress
// for the per-item progress slider.

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/api_error.dart';
import '../../core/utils/idempotency.dart';
import '../../domain/entities/order_entity.dart';
import '../state/auth_provider.dart';
import '../state/order_providers.dart';
import '../widgets/status_chip.dart';

// ── Ticker — rebuilds the elapsed-minutes display every 30s without
//    refetching from the server.
final _nowTickerProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    yield DateTime.now();
  }
});

enum _Filter { all, incoming, preparing, ready }

const _kOverdueMinutes = 15;

class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  _Filter _filter = _Filter.all;

  bool _matchesFilter(OrderEntity o) {
    switch (_filter) {
      case _Filter.all:
        return o.status == OrderStatus.confirmed ||
            o.status == OrderStatus.preparing ||
            o.status == OrderStatus.ready;
      case _Filter.incoming:
        return o.status == OrderStatus.confirmed;
      case _Filter.preparing:
        return o.status == OrderStatus.preparing;
      case _Filter.ready:
        return o.status == OrderStatus.ready;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(liveOrdersProvider);
    final kitchenOrders = orders.where(_matchesFilter).toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

    final incoming = orders.where((o) => o.status == OrderStatus.confirmed).length;
    final preparing = orders.where((o) => o.status == OrderStatus.preparing).length;
    final ready = orders.where((o) => o.status == OrderStatus.ready).length;

    return Scaffold(
      backgroundColor: slateBg,
      appBar: AppBar(
        title: const Text('KITCHEN DISPLAY'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              _WorkloadHeader(
                incoming: incoming,
                preparing: preparing,
                ready: ready,
              ),
              _FilterBar(
                value: _filter,
                onChanged: (v) => setState(() => _filter = v),
                counts: {
                  _Filter.incoming: incoming,
                  _Filter.preparing: preparing,
                  _Filter.ready: ready,
                },
              ),
            ],
          ),
        ),
      ),
      body: kitchenOrders.isEmpty
          ? const _EmptyKitchen()
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 340,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              itemCount: kitchenOrders.length,
              itemBuilder: (_, i) => _KitchenCard(order: kitchenOrders[i]),
            ),
    );
  }
}

// ── Workload header ─────────────────────────────────────────────────────────
class _WorkloadHeader extends StatelessWidget {
  final int incoming;
  final int preparing;
  final int ready;
  const _WorkloadHeader({
    required this.incoming,
    required this.preparing,
    required this.ready,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      color: slateBg,
      child: Row(
        children: [
          Expanded(child: _Stat('Incoming', incoming, amber)),
          const SizedBox(width: 8),
          Expanded(child: _Stat('Preparing', preparing, copperAccent)),
          const SizedBox(width: 8),
          Expanded(child: _Stat('Ready', ready, emerald)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text('$value',
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ── Filter chip bar ─────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final _Filter value;
  final ValueChanged<_Filter> onChanged;
  final Map<_Filter, int> counts;
  const _FilterBar({
    required this.value,
    required this.onChanged,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: slateBg,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          for (final f in _Filter.values) ...[
            _chip(f, _label(f), counts[f]),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  String _label(_Filter f) => switch (f) {
        _Filter.all => 'All',
        _Filter.incoming => 'Incoming',
        _Filter.preparing => 'Preparing',
        _Filter.ready => 'Ready',
      };

  Widget _chip(_Filter f, String label, int? count) {
    final selected = value == f;
    return GestureDetector(
      onTap: () => onChanged(f),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? copperAccent.withValues(alpha: 0.2) : slateCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? copperAccent : dividerColor,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  color: selected ? copperAccent : textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          if (count != null && count > 0 && f != _Filter.all) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count',
                  style: const TextStyle(
                      color: textPrimary, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Kitchen card ────────────────────────────────────────────────────────────
class _KitchenCard extends ConsumerWidget {
  final OrderEntity order;
  const _KitchenCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(_nowTickerProvider).value ?? DateTime.now();
    final elapsed = now.difference(order.updatedAt);
    final isOverdue = elapsed.inMinutes > _kOverdueMinutes;

    return Container(
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? crimson.withValues(alpha: 0.6) : dividerColor,
          width: isOverdue ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isOverdue
                  ? crimson.withValues(alpha: 0.1)
                  : copperAccent.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  '#${order.id.length > 8 ? order.id.substring(order.id.length - 6) : order.id}',
                  style: const TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              StatusChip(status: order.status),
            ]),
          ),
          // Body — items + meta
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.table_restaurant_outlined,
                        size: 12, color: textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(order.tableLabel,
                          style: const TextStyle(
                              color: textSecondary, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('${elapsed.inMinutes}m',
                        style: TextStyle(
                          color: isOverdue ? crimson : textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        )),
                  ]),
                  const SizedBox(height: 10),
                  ...order.items.map((item) => _ChefItemRow(
                        orderId: order.id,
                        item: item,
                      )),
                ],
              ),
            ),
          ),
          // Action footer
          _ActionFooter(order: order),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Per-item row with tap-for-actions ───────────────────────────────────────
class _ChefItemRow extends ConsumerWidget {
  final String orderId;
  final OrderItemEntity item;
  const _ChefItemRow({required this.orderId, required this.item});

  Color _progressColor(double p) {
    if (p >= 1.0) return emerald;
    if (p >= 0.5) return copperAccent;
    return textSecondary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showActionsSheet(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: slateSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: dividerColor),
        ),
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: copperAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text('×${item.quantity}',
                  style: const TextStyle(
                      color: copperAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item.name,
                    style: const TextStyle(
                        color: textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                if (item.notes?.isNotEmpty == true)
                  Text(item.notes!,
                      style: const TextStyle(
                          color: amber, fontSize: 10, fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.progress.clamp(0, 1),
                    backgroundColor: slateBg,
                    valueColor: AlwaysStoppedAnimation(_progressColor(item.progress)),
                    minHeight: 3,
                  ),
                ),
              ])),
        ]),
      ),
    );
  }

  void _showActionsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ItemActionsSheet(orderId: orderId, item: item),
    );
  }
}

class _ItemActionsSheet extends ConsumerStatefulWidget {
  final String orderId;
  final OrderItemEntity item;
  const _ItemActionsSheet({required this.orderId, required this.item});
  @override
  ConsumerState<_ItemActionsSheet> createState() => _ItemActionsSheetState();
}

class _ItemActionsSheetState extends ConsumerState<_ItemActionsSheet> {
  late double _progress;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _progress = widget.item.progress.clamp(0, 1);
  }

  Future<void> _pushProgress(double value) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progress = value;
    });
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.patch(
        '/orders/${widget.orderId}/items/${widget.item.id}/progress',
        data: {'progress': value},
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('item-progress-${widget.item.id}-$value'),
        }),
      );
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

  Future<void> _markUnavailable() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // `item.id` on the order line refers to the menu item id; the server's
      // /menu/:id/toggle flips availability for the menu document.
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.patch(
        '/menu/${widget.item.id}/toggle',
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('menu-toggle-${widget.item.id}'),
        }),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${widget.item.name} marked unavailable'),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: textSecondary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.item.name,
              style: const TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          Text('×${widget.item.quantity}',
              style: const TextStyle(color: textSecondary, fontSize: 12)),
          if (widget.item.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(widget.item.notes!,
                  style: const TextStyle(
                      color: amber, fontSize: 11, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center),
            ),
          ],
          const SizedBox(height: 20),
          // Progress slider — 0/0.5/1.0 are the meaningful stops
          Row(children: [
            const Text('Progress',
                style: TextStyle(color: textSecondary, fontSize: 12)),
            const Spacer(),
            Text('${(_progress * 100).round()}%',
                style: const TextStyle(
                    color: copperAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ]),
          Slider(
            value: _progress,
            min: 0,
            max: 1,
            divisions: 4,
            activeColor: copperAccent,
            inactiveColor: slateSurface,
            onChanged: (v) => setState(() => _progress = v),
            onChangeEnd: _pushProgress,
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.no_food_outlined, size: 16),
                label: const Text('Mark Unavailable'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: crimson,
                  side: BorderSide(color: crimson.withValues(alpha: 0.5)),
                ),
                onPressed: _busy ? null : _markUnavailable,
              ),
            ),
          ]),
        ]),
      );
}

// ── Order-level action footer ───────────────────────────────────────────────
class _ActionFooter extends ConsumerWidget {
  final OrderEntity order;
  const _ActionFooter({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // CONFIRMED → "Start Preparing"; PREPARING → "Mark Ready"; READY → done.
    OrderStatus? next;
    String label;
    Color color;
    IconData icon;
    switch (order.status) {
      case OrderStatus.confirmed:
        next = OrderStatus.preparing;
        label = 'Start Preparing';
        color = copperAccent;
        icon = Icons.play_arrow_rounded;
        break;
      case OrderStatus.preparing:
        next = OrderStatus.ready;
        label = 'Mark Ready';
        color = emerald;
        icon = Icons.check_circle_outline;
        break;
      case OrderStatus.ready:
        next = null;
        label = 'Awaiting Pickup';
        color = textSecondary;
        icon = Icons.timer_outlined;
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: slateBg,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: next == null ? slateSurface : color,
            foregroundColor: next == null ? textSecondary : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          onPressed: next == null
              ? null
              : () => _advance(context, ref, next!),
        ),
      ),
    );
  }

  Future<void> _advance(BuildContext context, WidgetRef ref, OrderStatus next) async {
    // Use the StateNotifier — it handles optimistic update + retry queue.
    await ref.read(liveOrdersProvider.notifier).updateStatus(order.id, next);
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────
class _EmptyKitchen extends StatelessWidget {
  const _EmptyKitchen();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: emerald.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('All caught up!',
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('No active kitchen orders',
                style: TextStyle(color: textSecondary, fontSize: 13)),
          ],
        ),
      );
}
