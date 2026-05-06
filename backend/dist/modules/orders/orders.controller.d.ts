import { OrdersService } from './orders.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { UpdateStatusDto } from './dto/update-status.dto';
export declare class OrdersController {
    private readonly ordersService;
    constructor(ordersService: OrdersService);
    getActive(): Promise<import("./order.schema").Order[]>;
    getById(id: string): Promise<import("./order.schema").Order>;
    create(dto: CreateOrderDto, req: any, idempotencyKey: string): Promise<import("./order.schema").Order>;
    updateStatus(id: string, dto: UpdateStatusDto, req: any, idempotencyKey: string): Promise<import("./order.schema").Order>;
    updateProgress(orderId: string, itemId: string, progress: number, req: any): Promise<void>;
}
