import { Model, Types } from 'mongoose';
import { Bill, BillDocument, PaymentMethod } from './bill.schema';
import { OrdersService } from '../orders/orders.service';
export declare class BillingService {
    private billModel;
    private ordersService;
    constructor(billModel: Model<BillDocument>, ordersService: OrdersService);
    generateBill(orderId: string, discountPercent?: number): Promise<import("mongoose").Document<unknown, {}, BillDocument, {}, {}> & Bill & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    }>;
    processPayment(billId: string, cashierId: string, paymentMethod: PaymentMethod, splitPayments?: {
        method: PaymentMethod;
        amount: number;
    }[], idempotencyKey?: string): Promise<import("mongoose").Document<unknown, {}, BillDocument, {}, {}> & Bill & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    }>;
    findByOrder(orderId: string): Promise<(import("mongoose").FlattenMaps<BillDocument> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    }) | null>;
    findAll(isPaid?: boolean): Promise<(import("mongoose").FlattenMaps<BillDocument> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    })[]>;
    getDailyRevenue(): Promise<any>;
}
