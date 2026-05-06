import { Document } from 'mongoose';
export type MenuItemDocument = MenuItem & Document;
declare class Variant {
    name: string;
    price: number;
}
declare class Modifier {
    name: string;
    extraPrice: number;
}
export declare class MenuItem {
    name: string;
    description?: string;
    category: string;
    basePrice: number;
    variants: Variant[];
    modifiers: Modifier[];
    isAvailable: boolean;
    imageUrl?: string;
    prepTimeMinutes: number;
    ingredients: {
        ingredientId: string;
        quantity: number;
        unit: string;
    }[];
}
export declare const MenuItemSchema: import("mongoose").Schema<MenuItem, import("mongoose").Model<MenuItem, any, any, any, Document<unknown, any, MenuItem, any, {}> & MenuItem & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}, any>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, MenuItem, Document<unknown, {}, import("mongoose").FlatRecord<MenuItem>, {}, import("mongoose").DefaultSchemaOptions> & import("mongoose").FlatRecord<MenuItem> & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}>;
export {};
