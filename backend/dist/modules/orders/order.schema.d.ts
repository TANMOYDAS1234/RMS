import { Document, Types } from 'mongoose';
export type OrderDocument = Order & Document;
export declare enum OrderStatus {
    CREATED = "created",
    CONFIRMED = "confirmed",
    PREPARING = "preparing",
    READY = "ready",
    SERVED = "served",
    BILLED = "billed",
    PAID = "paid",
    CLOSED = "closed"
}
export declare class OrderItem {
    itemId: string;
    name: string;
    quantity: number;
    unitPrice: number;
    progress: number;
    notes?: string;
}
export declare class Order {
    tableId: string;
    tableLabel: string;
    items: OrderItem[];
    status: OrderStatus;
    version: number;
    processedKeys: string[];
    waiterId?: string;
    notes?: string;
    subtotal: number;
    gstAmount: number;
    discountAmount: number;
    total: number;
    auditLog: {
        action: string;
        by: string;
        at: Date;
        meta?: object;
    }[];
}
export declare const OrderSchema: import("mongoose").Schema<Order, import("mongoose").Model<Order, any, any, any, Document<unknown, any, Order, any, {}> & Order & {
    _id: Types.ObjectId;
} & {
    __v: number;
}, any>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, Order, Document<unknown, {}, import("mongoose").FlatRecord<Order>, {}, import("mongoose").DefaultSchemaOptions> & import("mongoose").FlatRecord<Order> & {
    _id: Types.ObjectId;
} & {
    __v: number;
}>;
