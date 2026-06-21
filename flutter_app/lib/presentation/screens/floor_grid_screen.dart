// ─── Waiter Floor Grid ───────────────────────────────────────────────────────
//
// Visual seating chart — one tile per table, color-coded by status, with
// the active order summary inline when occupied. Tap an available table
// to open NewOrderScreen pre-selected; tap an occupied one to open the
// status sheet for its active order.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/api_error.dart';
import '../../domain/entities/order_entity.dart';
import '../state/auth_provider.dart';
import '../state/order_providers.dart';
import '../state/tables_provider.dart';

/// One row of multi-party capacity per table. Backed by
/// /sessions/branch/:branchId/seats which the backend computes in a
/// single round trip. Keyed by tableId for O(1) lookup from the tile.
final _branchSeatsProvider =
    FutureProvider.autoDispose<Map<String, Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  final branchId = ref.watch(authProvider).user?.branchId;
  if (branchId == null || branchId.isEmpty) return const {};
  final dio = createDioClient(token);
  final res = await dio.get('/sessions/branch/$branchId/seats');
  final list = (res.data as List).cast<Map<String, dynamic>>();
  return {
    for (final row in list)
      (row['tableId'] as String? ?? ''): row,
  };
});

class FloorGridScreen extends ConsumerWidget {
  const FloorGridScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(tablesProvider);
    final orders = ref.watch(liveOrdersProvider);
    // Best-effort multi-party occupancy. If the call fails we render the
    // legacy single-party fallback rather than blocking the whole grid.
    final seatsAsync = ref.watch(_branchSeatsProvider);
    final seatsByTable = seatsAsync.maybeWhen(
      data: (m) => m,
      orElse: () => const <String, Map<String, dynamic>>{},
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('FLOOR PLAN'),
      ),
      body: RefreshIndicator(
        color: copperAccent,
        backgroundColor: slateCard,
        onRefresh: () async {
          ref.invalidate(tablesProvider);
          ref.invalidate(_branchSeatsProvider);
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
                    seats: seatsByTable[tables[i].id],
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
  /// Multi-party occupancy data for this table from
  /// /sessions/branch/:branchId/seats. Null when the call hasn't loaded
  /// yet or the table is empty — we fall back to the legacy "one party
  /// per occupied table" rendering in that case.
  final Map<String, dynamic>? seats;
  const _TableTile({required this.table, this.activeOrder, this.seats});

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
    final parties = (seats?['activeParties'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const [];
    final occupied = (seats?['occupied'] as num?)?.toInt() ?? 0;
    final capacity = (seats?['capacity'] as num?)?.toInt() ?? table.capacity;
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
            // Seat fraction — "3/4 seats" when we have multi-party data,
            // otherwise the simple capacity tag.
            Text(
              parties.isNotEmpty || occupied > 0
                  ? '$occupied/$capacity'
                  : '${table.capacity}p',
              style: const TextStyle(
                  color: textSecondary, fontSize: 10),
            ),
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
                  // Multi-party rendering — each active party shows as a
                  // small pill with its label + size, billPending tinted
                  // amber. Falls through to the legacy single-order block
                  // when there's no party data yet.
                  if (parties.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final p in parties)
                          _PartyPill(
                            label: (p['partyLabel'] as String? ?? '').isEmpty
                                ? '?'
                                : (p['partyLabel'] as String),
                            size: (p['partySize'] as num?)?.toInt() ?? 1,
                            billPending: p['billPending'] == true,
                          ),
                      ],
                    )
                  else if (hasOrder) ...[
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

class _PartyPill extends StatelessWidget {
  final String label;
  final int size;
  final bool billPending;
  const _PartyPill({
    required this.label,
    required this.size,
    required this.billPending,
  });

  @override
  Widget build(BuildContext context) {
    final color = billPending ? amber : copperAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w800)),
        const SizedBox(width: 3),
        Text('· $size',
            style: TextStyle(color: color, fontSize: 9)),
        if (billPending) ...[
          const SizedBox(width: 2),
          Icon(Icons.receipt_outlined, color: color, size: 9),
        ],
      ]),
    );
  }
}
