import { InventoryService } from './inventory.service';
declare class CreateIngredientDto {
    name: string;
    unit: string;
    currentStock: number;
    lowStockThreshold: number;
    costPerUnit?: number;
}
declare class AdjustStockDto {
    delta: number;
    reason: string;
}
export declare class InventoryController {
    private readonly inventoryService;
    constructor(inventoryService: InventoryService);
    findAll(): Promise<(import("mongoose").FlattenMaps<import("./ingredient.schema").IngredientDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    })[]>;
    lowStock(): Promise<(import("mongoose").FlattenMaps<import("./ingredient.schema").IngredientDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    })[]>;
    findOne(id: string): Promise<import("mongoose").FlattenMaps<import("./ingredient.schema").IngredientDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    create(dto: CreateIngredientDto): Promise<import("mongoose").Document<unknown, {}, import("./ingredient.schema").IngredientDocument, {}, {}> & import("./ingredient.schema").Ingredient & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    adjust(id: string, dto: AdjustStockDto, req: any): Promise<import("mongoose").Document<unknown, {}, import("./ingredient.schema").IngredientDocument, {}, {}> & import("./ingredient.schema").Ingredient & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    update(id: string, dto: Partial<CreateIngredientDto>): Promise<import("mongoose").FlattenMaps<import("./ingredient.schema").IngredientDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    delete(id: string): Promise<{
        deleted: boolean;
    }>;
}
export {};
