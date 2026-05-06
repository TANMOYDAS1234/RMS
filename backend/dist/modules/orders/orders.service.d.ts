import { Model } from 'mongoose';
import { Order, OrderDocument } from './order.schema';
import { CreateOrderDto } from './dto/create-order.dto';
import { UpdateStatusDto } from './dto/update-status.dto';
import { OrdersGateway } from '../../gateways/orders.gateway';
export declare class OrdersService {
    private orderModel;
    private readonly gateway;
    constructor(orderModel: Model<OrderDocument>, gateway: OrdersGateway);
    create(dto: CreateOrderDto, userId: string, idempotencyKey: string): Promise<Order>;
    getActiveOrders(): Promise<Order[]>;
    getById(id: string): Promise<Order>;
    updateStatus(id: string, dto: UpdateStatusDto, userId: string, idempotencyKey: string): Promise<Order>;
    updateItemProgress(orderId: string, itemId: string, progress: number, userId: string): Promise<void>;
}
