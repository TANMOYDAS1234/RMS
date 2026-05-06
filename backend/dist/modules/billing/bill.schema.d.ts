import { Document, Types } from 'mongoose';
export type BillDocument = Bill & Document;
export declare enum PaymentMethod {
    CASH = "cash",
    CARD = "card",
    UPI = "upi",
    SPLIT = "split"
}
declare class SplitPayment {
    method: PaymentMethod;
    amount: number;
}
export declare class Bill {
    orderId: Types.ObjectId;
    tableLabel: string;
    subtotal: number;
    discountAmount: number;
    discountPercent: number;
    gstAmount: number;
    total: number;
    paymentMethod?: PaymentMethod;
    splitPayments: SplitPayment[];
    isPaid: boolean;
    paidAt?: Date;
    cashierId?: string;
    processedKeys: string[];
}
export declare const BillSchema: import("mongoose").Schema<Bill, import("mongoose").Model<Bill, any, any, any, Document<unknown, any, Bill, any, {}> & Bill & {
    _id: Types.ObjectId;
} & {
    __v: number;
}, any>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, Bill, Document<unknown, {}, import("mongoose").FlatRecord<Bill>, {}, import("mongoose").DefaultSchemaOptions> & import("mongoose").FlatRecord<Bill> & {
    _id: Types.ObjectId;
} & {
    __v: number;
}>;
export {};
