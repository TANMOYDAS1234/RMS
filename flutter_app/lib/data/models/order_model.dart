// ─── Order Data Model (JSON ↔ Entity) ────────────────────────────────────────

import '../../domain/entities/order_entity.dart';

class OrderItemModel {
  final String id;
  final String name;
  final double progress;
  final int quantity;
  final double unitPrice;
  final String? notes;

  const OrderItemModel({
    required this.id,
    required this.name,
    required this.progress,
    required this.quantity,
    required this.unitPrice,
    this.notes,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => OrderItemModel(
        // Backend sub-document field is `itemId` (the menu item _id);
        // sub-docs don't get their own _id. Older serializers used `id`
        // or `_id`, so we accept all three. Without this fallback the
        // chef KDS PATCH builds an `/items//progress` URL with an empty
        // segment and the server 404s — the "can't patch order" bug.
        id: json['itemId'] ?? json['_id'] ?? json['id'] ?? '',
        name: json['name'] ?? '',
        progress: (json['progress'] ?? 0).toDouble(),
        quantity: json['quantity'] ?? 1,
        unitPrice: (json['unitPrice'] ?? 0).toDouble(),
        notes: json['notes'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'progress': progress,
        'quantity': quantity,
        'unitPrice': unitPrice,
        if (notes != null) 'notes': notes,
      };

  OrderItemEntity toEntity() => OrderItemEntity(
        id: id,
        name: name,
        progress: progress,
        quantity: quantity,
        unitPrice: unitPrice,
        notes: notes,
      );
}

class OrderModel {
  final String id;
  final String tableLabel;
  final List<OrderItemModel> items;
  final String status;
  final int version;
  final String syncStatus;
  final DateTime updatedAt;

  const OrderModel({
    required this.id,
    required this.tableLabel,
    required this.items,
    required this.status,
    required this.version,
    required this.syncStatus,
    required this.updatedAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id: json['_id'] ?? json['id'] ?? '',
        tableLabel: json['tableLabel'] ?? '',
        items: (json['items'] as List? ?? [])
            .map((i) => OrderItemModel.fromJson(i))
            .toList(),
        status: json['status'] ?? 'created',
        version: json['version'] ?? 1,
        syncStatus: json['syncStatus'] ?? 'SYNCED',
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tableLabel': tableLabel,
        'items': items.map((i) => i.toJson()).toList(),
        'status': status,
        'version': version,
        'syncStatus': syncStatus,
        'updatedAt': updatedAt.toIso8601String(),
      };

  OrderEntity toEntity() => OrderEntity(
        id: id,
        tableLabel: tableLabel,
        items: items.map((i) => i.toEntity()).toList(),
        status: OrderStatus.values.firstWhere(
          (s) => s.statusName == status,
          orElse: () => OrderStatus.created,
        ),
        version: version,
        syncStatus: SyncStatus.values.firstWhere(
          (s) => s.statusName.toUpperCase() == syncStatus,
          orElse: () => SyncStatus.synced,
        ),
        updatedAt: updatedAt,
      );
}
