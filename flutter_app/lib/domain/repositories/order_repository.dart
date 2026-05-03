// ─── Order Repository Contract ───────────────────────────────────────────────

import 'package:dartz/dartz.dart';
import '../entities/order_entity.dart';
import '../../core/errors/failures.dart';

abstract class OrderRepository {
  Future<Either<Failure, List<OrderEntity>>> getActiveOrders();
  Future<Either<Failure, OrderEntity>> getOrderById(String id);
  Future<Either<Failure, OrderEntity>> createOrder(OrderEntity order);
  Future<Either<Failure, OrderEntity>> updateOrderStatus(
    String id,
    OrderStatus newStatus,
    int currentVersion,
    String idempotencyKey,
  );
  Stream<OrderEntity> watchOrder(String id);
  Stream<List<OrderEntity>> watchActiveOrders();
}
