// ─── Order Card Widget ───────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/order_entity.dart';
import '../../core/config/app_theme.dart';
import 'status_chip.dart';
import 'item_row.dart';

class OrderCard extends StatelessWidget {
  final OrderEntity order;
  final VoidCallback? onStatusTap;

  const OrderCard({super.key, required this.order, this.onStatusTap});

  @override
  Widget build(BuildContext context) {
    final isUrgent = order.isUrgent;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUrgent
              ? copperAccent.withValues(alpha: 0.5)
              : dividerColor,
          width: isUrgent ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isUrgent
                ? copperAccent.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(color: dividerColor, height: 1),
          _buildItems(),
          const Divider(color: dividerColor, height: 1),
          _buildFooter(),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.05, end: 0, duration: 350.ms, curve: Curves.easeOut);
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Row(
          children: [
            // Urgent indicator dot
            if (order.isUrgent)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: copperAccent,
                  shape: BoxShape.circle,
                ),
              ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 600.ms).then().fadeOut(duration: 600.ms),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.id}',
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.table_restaurant_outlined,
                          size: 12, color: textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        order.tableLabel,
                        style: const TextStyle(
                            color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onStatusTap,
              child: StatusChip(status: order.status),
            ),
          ],
        ),
      );

  Widget _buildItems() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: order.items.map((item) => ItemRow(item: item)).toList(),
        ),
      );

  Widget _buildFooter() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            SyncStatusBadge(syncStatus: order.syncStatus),
            const SizedBox(width: 6),
            const Icon(Icons.history, size: 12, color: textSecondary),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                _timeAgo(order.updatedAt),
                style: const TextStyle(color: textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: slateSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'v${order.version}',
                style: const TextStyle(
                    color: textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '₹${order.total.toStringAsFixed(2)}',
              style: const TextStyle(
                color: copperAccent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return DateFormat('HH:mm').format(dt);
  }
}
