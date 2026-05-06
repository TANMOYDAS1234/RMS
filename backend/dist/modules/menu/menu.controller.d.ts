import { MenuService } from './menu.service';
declare class CreateMenuItemDto {
    name: string;
    description?: string;
    category: string;
    basePrice: number;
    variants?: any[];
    modifiers?: any[];
    isAvailable?: boolean;
    imageUrl?: string;
    prepTimeMinutes?: number;
}
export declare class MenuController {
    private readonly menuService;
    constructor(menuService: MenuService);
    findAll(category?: string): Promise<(import("mongoose").FlattenMaps<import("./menu.schema").MenuItemDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    })[]>;
    findOne(id: string): Promise<import("mongoose").FlattenMaps<import("./menu.schema").MenuItemDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    create(dto: CreateMenuItemDto): Promise<import("mongoose").Document<unknown, {}, import("./menu.schema").MenuItemDocument, {}, {}> & import("./menu.schema").MenuItem & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    update(id: string, dto: Partial<CreateMenuItemDto>): Promise<import("mongoose").FlattenMaps<import("./menu.schema").MenuItemDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    toggle(id: string): Promise<import("mongoose").Document<unknown, {}, import("./menu.schema").MenuItemDocument, {}, {}> & import("./menu.schema").MenuItem & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    delete(id: string): Promise<{
        deleted: boolean;
    }>;
}
export {};
