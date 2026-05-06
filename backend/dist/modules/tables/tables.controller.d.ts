import { TablesService } from './tables.service';
import { TableStatus } from './table.schema';
declare class CreateTableDto {
    label: string;
    capacity: number;
}
declare class UpdateTableStatusDto {
    status: TableStatus;
    activeOrderId?: string;
}
export declare class TablesController {
    private readonly tablesService;
    constructor(tablesService: TablesService);
    findAll(): Promise<(import("mongoose").FlattenMaps<import("./table.schema").TableDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    })[]>;
    findOne(id: string): Promise<import("mongoose").FlattenMaps<import("./table.schema").TableDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    create(dto: CreateTableDto): Promise<import("mongoose").Document<unknown, {}, import("./table.schema").TableDocument, {}, {}> & import("./table.schema").Table & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    updateStatus(id: string, dto: UpdateTableStatusDto): Promise<import("mongoose").FlattenMaps<import("./table.schema").TableDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    delete(id: string): Promise<{
        deleted: boolean;
    }>;
}
export {};
