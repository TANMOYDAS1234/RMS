// ─── Kitchen Display Screen ──────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/config/app_theme.dart';
import '../../domain/entities/order_entity.dart';
import '../state/order_providers.dart';
import '../widgets/item_row.dart';
import '../widgets/status_chip.dart';

class KitchenScreen extends ConsumerWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(liveOrdersProvider);
    final kitchenOrders = orders
        .where((o) =>
            o.status == OrderStatus.confirmed ||
            o.status == OrderStatus.preparing)
        .toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

    return Scaffold(
      backgroundColor: slateBg,
      appBar: AppBar(
        title: const Text('KITCHEN DISPLAY'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${kitchenOrders.length} Active',
                style: const TextStyle(
                    color: copperAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: kitchenOrders.isEmpty
          ? _EmptyKitchen()
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              itemCount: kitchenOrders.length,
              itemBuilder: (_, i) => _KitchenCard(order: kitchenOrders[i]),
            ),
    );
  }
}

class _KitchenCard extends StatelessWidget {
  final OrderEntity order;
  const _KitchenCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(order.updatedAt);
    final isOverdue = elapsed.inMinutes > 15;

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isOverdue
                  ? crimson.withValues(alpha: 0.1)
                  : copperAccent.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
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
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.table_restaurant_outlined,
                          size: 12, color: textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(order.tableLabel,
                            style: const TextStyle(
                                color: textSecondary, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        '${elapsed.inMinutes}m',
                        style: TextStyle(
                          color: isOverdue ? crimson : textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...order.items.map((item) => ItemRow(item: item)),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _EmptyKitchen extends StatelessWidget {
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
