// ─── Metrics Ribbon Widget ───────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/config/app_theme.dart';

class MetricsRibbon extends StatelessWidget {
  final int activeOrders;
  final int occupiedTables;
  final int totalTables;
  final double revenue;

  const MetricsRibbon({
    super.key,
    required this.activeOrders,
    required this.occupiedTables,
    required this.totalTables,
    required this.revenue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dividerColor),
      ),
      child: Row(
        children: [
          _MetricTile(
            icon: Icons.receipt_long_outlined,
            label: 'Active',
            value: '$activeOrders',
            color: copperAccent,
          ),
          _Divider(),
          _MetricTile(
            icon: Icons.table_restaurant_outlined,
            label: 'Tables',
            value: '$occupiedTables/$totalTables',
            color: roseGold,
          ),
          _Divider(),
          _MetricTile(
            icon: Icons.attach_money_outlined,
            label: 'Revenue',
            value: revenue < 1000
                ? '₹${revenue.toStringAsFixed(0)}'
                : '₹${(revenue / 1000).toStringAsFixed(1)}k',
            color: emerald,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 50,
        color: dividerColor,
      );
}
