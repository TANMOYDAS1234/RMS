import { Model } from 'mongoose';
import { Ingredient, IngredientDocument } from './ingredient.schema';
export declare class InventoryService {
    private ingredientModel;
    constructor(ingredientModel: Model<IngredientDocument>);
    findAll(): Promise<(import("mongoose").FlattenMaps<IngredientDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    })[]>;
    findLowStock(): Promise<(import("mongoose").FlattenMaps<IngredientDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    })[]>;
    findById(id: string): Promise<import("mongoose").FlattenMaps<IngredientDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    create(dto: {
        name: string;
        unit: string;
        currentStock: number;
        lowStockThreshold: number;
        costPerUnit?: number;
    }): Promise<import("mongoose").Document<unknown, {}, IngredientDocument, {}, {}> & Ingredient & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    adjustStock(id: string, delta: number, reason: string, by: string): Promise<import("mongoose").Document<unknown, {}, IngredientDocument, {}, {}> & Ingredient & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    update(id: string, dto: any): Promise<import("mongoose").FlattenMaps<IngredientDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    delete(id: string): Promise<{
        deleted: boolean;
    }>;
}
