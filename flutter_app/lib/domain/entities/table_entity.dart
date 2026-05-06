// ─── Table Domain Entity ─────────────────────────────────────────────────────

enum TableStatus { available, occupied, reserved, cleaning }

class TableEntity {
  final String id;
  final String label;
  final int capacity;
  final TableStatus status;
  final String? activeOrderId;

  const TableEntity({
    required this.id,
    required this.label,
    required this.capacity,
    required this.status,
    this.activeOrderId,
  });
}
