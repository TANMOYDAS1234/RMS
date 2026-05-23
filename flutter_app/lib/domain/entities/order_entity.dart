// ─── Order Domain Entities ───────────────────────────────────────────────────

enum OrderStatus {
  created,
  confirmed,
  preparing,
  ready,
  served,
  billed,
  paid,
  closed;

  String get statusName => toString().split('.').last;
  String get label => statusName[0].toUpperCase() + statusName.substring(1);

  bool canTransitionTo(OrderStatus next) {
    const transitions = {
      OrderStatus.created: [OrderStatus.confirmed],
      OrderStatus.confirmed: [OrderStatus.preparing],
      OrderStatus.preparing: [OrderStatus.ready],
      OrderStatus.ready: [OrderStatus.served],
      OrderStatus.served: [OrderStatus.billed],
      OrderStatus.billed: [OrderStatus.paid],
      OrderStatus.paid: [OrderStatus.closed],
    };
    return transitions[this]?.contains(next) ?? false;
  }
}

enum SyncStatus {
  synced,
  pending,
  conflict;

  String get statusName => toString().split('.').last;
}

class OrderItemEntity {
  final String id;
  final String name;
  final double progress; // 0.0 – 1.0 cooking progress
  final int quantity;
  final double unitPrice;
  final String? notes;

  const OrderItemEntity({
    required this.id,
    required this.name,
    required this.progress,
    required this.quantity,
    required this.unitPrice,
    this.notes,
  });

  OrderItemEntity copyWith({double? progress}) =>
      OrderItemEntity(
        id: id,
        name: name,
        progress: progress ?? this.progress,
        quantity: quantity,
        unitPrice: unitPrice,
        notes: notes,
      );
}

class OrderEntity {
  final String id;
  final String tableLabel;
  final List<OrderItemEntity> items;
  final OrderStatus status;
  final int version;
  final SyncStatus syncStatus;
  final DateTime updatedAt;
  final String? idempotencyKey;

  const OrderEntity({
    required this.id,
    required this.tableLabel,
    required this.items,
    required this.status,
    required this.version,
    this.syncStatus = SyncStatus.synced,
    required this.updatedAt,
    this.idempotencyKey,
  });

  double get total =>
      items.fold(0, (sum, i) => sum + i.unitPrice * i.quantity);

  bool get isUrgent =>
      status == OrderStatus.ready || status == OrderStatus.served;

  OrderEntity copyWith({
    OrderStatus? status,
    List<OrderItemEntity>? items,
    int? version,
    SyncStatus? syncStatus,
  }) =>
      OrderEntity(
        id: id,
        tableLabel: tableLabel,
        items: items ?? this.items,
        status: status ?? this.status,
        version: version ?? this.version,
        syncStatus: syncStatus ?? this.syncStatus,
        updatedAt: DateTime.now(),
        idempotencyKey: idempotencyKey,
      );
}
