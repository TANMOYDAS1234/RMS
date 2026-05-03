// ─── Status Chip Widget ──────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../domain/entities/order_entity.dart';
import '../../core/config/app_theme.dart';

class StatusChip extends StatelessWidget {
  final OrderStatus status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _config(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            status.label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData) _config(OrderStatus s) => switch (s) {
        OrderStatus.created => (textSecondary, Icons.add_circle_outline),
        OrderStatus.confirmed => (amber, Icons.check_circle_outline),
        OrderStatus.preparing => (copperAccent, Icons.local_fire_department),
        OrderStatus.ready => (emerald, Icons.done_all),
        OrderStatus.served => (roseGold, Icons.room_service_outlined),
        OrderStatus.billed => (Colors.blue, Icons.receipt_outlined),
        OrderStatus.paid => (emerald, Icons.payments_outlined),
        OrderStatus.closed => (textSecondary, Icons.lock_outline),
      };
}

class SyncStatusBadge extends StatelessWidget {
  final SyncStatus syncStatus;
  const SyncStatusBadge({super.key, required this.syncStatus});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (syncStatus) {
      SyncStatus.synced => (Icons.cloud_done_outlined, emerald, 'Synced'),
      SyncStatus.pending => (Icons.cloud_upload_outlined, amber, 'Pending'),
      SyncStatus.conflict => (Icons.warning_amber_outlined, crimson, 'Conflict'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
