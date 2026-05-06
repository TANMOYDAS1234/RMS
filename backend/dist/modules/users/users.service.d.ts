import { Model } from 'mongoose';
import { User, UserDocument, UserRole } from './user.schema';
export declare class UsersService {
    private userModel;
    constructor(userModel: Model<UserDocument>);
    create(dto: {
        name: string;
        email: string;
        password: string;
        role?: UserRole;
    }): Promise<import("mongoose").Document<unknown, {}, UserDocument, {}, {}> & User & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    findAll(): Promise<(import("mongoose").FlattenMaps<UserDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    })[]>;
    findById(id: string): Promise<import("mongoose").FlattenMaps<UserDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    update(id: string, dto: Partial<{
        name: string;
        role: UserRole;
        isActive: boolean;
        fcmToken: string;
    }>): Promise<import("mongoose").FlattenMaps<UserDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }>;
    delete(id: string): Promise<{
        deleted: boolean;
    }>;
}
