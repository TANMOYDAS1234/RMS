import { Document } from 'mongoose';
export type UserDocument = User & Document;
export declare enum UserRole {
    ADMIN = "admin",
    MANAGER = "manager",
    WAITER = "waiter",
    CHEF = "chef",
    CASHIER = "cashier",
    CUSTOMER = "customer"
}
export declare class User {
    name: string;
    email: string;
    password: string;
    role: UserRole;
    fcmToken?: string;
    isActive: boolean;
}
export declare const UserSchema: import("mongoose").Schema<User, import("mongoose").Model<User, any, any, any, Document<unknown, any, User, any, {}> & User & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}, any>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, User, Document<unknown, {}, import("mongoose").FlatRecord<User>, {}, import("mongoose").DefaultSchemaOptions> & import("mongoose").FlatRecord<User> & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}>;
