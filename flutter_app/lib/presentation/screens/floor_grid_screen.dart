// ─── Waiter Floor Grid ───────────────────────────────────────────────────────
//
// Visual seating chart — one tile per table, color-coded by status, with
// the active order summary inline when occupied. Tap an available table
// to open NewOrderScreen pre-selected; tap an occupied one to open the
// status sheet for its active order.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_theme.dart';
import '../../core/utils/api_error.dart';
import '../../domain/entities/order_entity.dart';
import '../state/order_providers.dart';
import '../state/tables_provider.dart';

class FloorGridScreen extends ConsumerWidget {
  const FloorGridScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(tablesProvider);
    final orders = ref.watch(liveOrdersProvider);

    return Scaffold(
      backgroundColor: slateBg,
      appBar: AppBar(
        title: const Text('FLOOR PLAN'),
        backgroundColor: slateBg,
      ),
      body: RefreshIndicator(
        color: copperAccent,
        backgroundColor: slateCard,
        onRefresh: () async {
          ref.invalidate(tablesProvider);
          ref.read(liveOrdersProvider.notifier).refresh();
        },
        child: tablesAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: copperAccent)),
          error: (e, _) => Center(
              child: Text(describeApiError(e),
                  style: const TextStyle(color: crimson))),
          data: (tables) {
            if (tables.isEmpty) {
              return const Center(
                child: Text('No tables configured yet.',
                    style: TextStyle(color: textSecondary)),
              );
            }
            final available = tables.where((t) => t.status == 'available').length;
            final occupied = tables.where((t) => t.status == 'occupied').length;
            final cleaning = tables.where((t) => t.status == 'cleaning').length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                _Legend(
                  available: available,
                  occupied: occupied,
                  cleaning: cleaning,
                  total: tables.length,
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 170,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: tables.length,
                  itemBuilder: (_, i) => _TableTile(
                    table: tables[i],
                    // The order at this table, if there is one. Match by
                    // tableId so re-used tables still resolve correctly.
                    activeOrder: orders.cast<OrderEntity?>().firstWhere(
                          (o) =>
                              o?.tableLabel == tables[i].label &&
                              o?.status != OrderStatus.paid &&
                              o?.status != OrderStatus.closed,
                          orElse: () => null,
                        ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final int available;
  final int occupied;
  final int cleaning;
  final int total;
  const _Legend({
    required this.available,
    required this.occupied,
    required this.cleaning,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dividerColor),
      ),
      child: Row(children: [
        _LegendChip(label: 'Available', count: available, color: emerald),
        const SizedBox(width: 6),
        _LegendChip(label: 'Occupied', count: occupied, color: copperAccent),
        const SizedBox(width: 6),
        _LegendChip(label: 'Cleaning', count: cleaning, color: amber),
        const Spacer(),
        Text('$total tables',
            style: const TextStyle(color: textSecondary, fontSize: 11)),
      ]),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _LegendChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label.toUpperCase(),
              style: TextStyle(
                  color: color, fontSize: 9, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          Text('$count',
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _TableTile extends StatelessWidget {
  final TableModel table;
  final OrderEntity? activeOrder;
  const _TableTile({required this.table, this.activeOrder});

  Color get _statusColor {
    switch (table.status) {
      case 'available':
        return emerald;
      case 'occupied':
        return copperAccent;
      case 'reserved':
        return roseGold;
      case 'cleaning':
        return amber;
      default:
        return textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasOrder = activeOrder != null;
    return Container(
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _statusColor.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.12),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: _statusColor, shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(table.status.toUpperCase(),
                style: TextStyle(
                    color: _statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
            const Spacer(),
            Text('${table.capacity}p',
                style: const TextStyle(
                    color: textSecondary, fontSize: 10)),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(table.label,
                      style: const TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  if (hasOrder) ...[
                    Row(children: [
                      const Icon(Icons.receipt_long_outlined,
                          color: copperAccent, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(
                              '${activeOrder!.items.length} item${activeOrder!.items.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                  color: textSecondary, fontSize: 11),
                              overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 2),
                    Text('₹${activeOrder!.total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: copperAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ] else
                    const Text('Tap to seat',
                        style:
                            TextStyle(color: textSecondary, fontSize: 11)),
                ]),
          ),
        ),
      ]),
    );
  }
}
