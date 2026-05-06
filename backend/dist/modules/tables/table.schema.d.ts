import { Document } from 'mongoose';
export type TableDocument = Table & Document;
export declare enum TableStatus {
    AVAILABLE = "available",
    OCCUPIED = "occupied",
    RESERVED = "reserved",
    CLEANING = "cleaning"
}
export declare class Table {
    label: string;
    capacity: number;
    status: TableStatus;
    activeOrderId?: string;
    qrCode?: string;
}
export declare const TableSchema: import("mongoose").Schema<Table, import("mongoose").Model<Table, any, any, any, Document<unknown, any, Table, any, {}> & Table & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}, any>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, Table, Document<unknown, {}, import("mongoose").FlatRecord<Table>, {}, import("mongoose").DefaultSchemaOptions> & import("mongoose").FlatRecord<Table> & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}>;
