import { BillingService } from './billing.service';
import { PaymentMethod } from './bill.schema';
declare class GenerateBillDto {
    discountPercent?: number;
}
declare class PaymentDto {
    paymentMethod: PaymentMethod;
    splitPayments?: {
        method: PaymentMethod;
        amount: number;
    }[];
}
export declare class BillingController {
    private readonly billingService;
    constructor(billingService: BillingService);
    findAll(isPaid?: string): Promise<(import("mongoose").FlattenMaps<import("./bill.schema").BillDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    })[]>;
    dailyRevenue(): Promise<any>;
    findByOrder(orderId: string): Promise<(import("mongoose").FlattenMaps<import("./bill.schema").BillDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }) | null>;
    generate(orderId: string, dto: GenerateBillDto): Promise<import("mongoose").Document<unknown, {}, import("./bill.schema").BillDocument, {}, {}> & import("./bill.schema").Bill & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    pay(id: string, dto: PaymentDto, req: any, key: string): Promise<import("mongoose").Document<unknown, {}, import("./bill.schema").BillDocument, {}, {}> & import("./bill.schema").Bill & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
}
export {};
