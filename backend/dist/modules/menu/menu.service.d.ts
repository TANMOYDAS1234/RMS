import { Model } from 'mongoose';
import { MenuItem, MenuItemDocument } from './menu.schema';
export declare class MenuService {
    private menuModel;
    constructor(menuModel: Model<MenuItemDocument>);
    findAll(category?: string): Promise<(import("mongoose").FlattenMaps<MenuItemDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    })[]>;
    findById(id: string): Promise<import("mongoose").FlattenMaps<MenuItemDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    create(dto: any): Promise<import("mongoose").Document<unknown, {}, MenuItemDocument, {}, {}> & MenuItem & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    update(id: string, dto: any): Promise<import("mongoose").FlattenMaps<MenuItemDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    delete(id: string): Promise<{
        deleted: boolean;
    }>;
    toggleAvailability(id: string): Promise<import("mongoose").Document<unknown, {}, MenuItemDocument, {}, {}> & MenuItem & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
}
