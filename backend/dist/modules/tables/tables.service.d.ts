import { Model } from 'mongoose';
import { Table, TableDocument, TableStatus } from './table.schema';
export declare class TablesService {
    private tableModel;
    constructor(tableModel: Model<TableDocument>);
    findAll(): Promise<(import("mongoose").FlattenMaps<TableDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    })[]>;
    findById(id: string): Promise<import("mongoose").FlattenMaps<TableDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    create(dto: {
        label: string;
        capacity: number;
    }): Promise<import("mongoose").Document<unknown, {}, TableDocument, {}, {}> & Table & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    updateStatus(id: string, status: TableStatus, activeOrderId?: string): Promise<import("mongoose").FlattenMaps<TableDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    delete(id: string): Promise<{
        deleted: boolean;
    }>;
}
