// ─── Item Row Widget ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../domain/entities/order_entity.dart';
import '../../core/config/app_theme.dart';

class ItemRow extends StatelessWidget {
  final OrderItemEntity item;
  const ItemRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final progressColor = _progressColor(item.progress);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                'x${item.quantity}',
                style: const TextStyle(color: textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                '${(item.progress * 100).toInt()}%',
                style: TextStyle(
                  color: progressColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.progress,
              backgroundColor: slateSurface,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 5,
            ),
          ).animate().fadeIn(duration: 400.ms),
        ],
      ),
    );
  }

  Color _progressColor(double p) {
    if (p >= 1.0) return emerald;
    if (p >= 0.6) return copperAccent;
    if (p >= 0.3) return amber;
    return crimson;
  }
}
