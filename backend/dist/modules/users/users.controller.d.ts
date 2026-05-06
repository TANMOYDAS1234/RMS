import { UsersService } from './users.service';
import { UserRole } from './user.schema';
declare class CreateUserDto {
    name: string;
    email: string;
    password: string;
    role?: UserRole;
}
declare class UpdateUserDto {
    name?: string;
    role?: UserRole;
    isActive?: boolean;
}
export declare class UsersController {
    private readonly usersService;
    constructor(usersService: UsersService);
    findAll(): Promise<(import("mongoose").FlattenMaps<import("./user.schema").UserDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    })[]>;
    findOne(id: string): Promise<import("mongoose").FlattenMaps<import("./user.schema").UserDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    create(dto: CreateUserDto): Promise<import("mongoose").Document<unknown, {}, import("./user.schema").UserDocument, {}, {}> & import("./user.schema").User & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    update(id: string, dto: UpdateUserDto): Promise<import("mongoose").FlattenMaps<import("./user.schema").UserDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    delete(id: string): Promise<{
        deleted: boolean;
    }>;
}
export {};
