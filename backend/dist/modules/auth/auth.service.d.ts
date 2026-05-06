import { JwtService } from '@nestjs/jwt';
import { Model } from 'mongoose';
import { UserDocument } from '../users/user.schema';
export declare class AuthService {
    private userModel;
    private jwtService;
    constructor(userModel: Model<UserDocument>, jwtService: JwtService);
    login(email: string, password: string): Promise<{
        accessToken: string;
        user: {
            id: import("mongoose").Types.ObjectId;
            name: string;
            email: string;
            role: import("../users/user.schema").UserRole;
        };
    }>;
    validateToken(payload: any): Promise<(import("mongoose").FlattenMaps<UserDocument> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    }) | null>;
}
