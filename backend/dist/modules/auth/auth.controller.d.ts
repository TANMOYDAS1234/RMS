import { AuthService } from './auth.service';
declare class LoginDto {
    email: string;
    password: string;
}
export declare class AuthController {
    private readonly authService;
    constructor(authService: AuthService);
    login(dto: LoginDto): Promise<{
        accessToken: string;
        user: {
            id: import("mongoose").Types.ObjectId;
            name: string;
            email: string;
            role: import("../users/user.schema").UserRole;
        };
    }>;
}
export {};
