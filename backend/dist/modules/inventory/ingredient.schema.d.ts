import { Document } from 'mongoose';
export type IngredientDocument = Ingredient & Document;
export declare class Ingredient {
    name: string;
    unit: string;
    currentStock: number;
    lowStockThreshold: number;
    costPerUnit: number;
    stockLog: {
        delta: number;
        reason: string;
        by: string;
        at: Date;
    }[];
}
export declare const IngredientSchema: import("mongoose").Schema<Ingredient, import("mongoose").Model<Ingredient, any, any, any, Document<unknown, any, Ingredient, any, {}> & Ingredient & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}, any>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, Ingredient, Document<unknown, {}, import("mongoose").FlatRecord<Ingredient>, {}, import("mongoose").DefaultSchemaOptions> & import("mongoose").FlatRecord<Ingredient> & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}>;
