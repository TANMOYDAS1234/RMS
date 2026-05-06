"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.IdempotencyInterceptor = void 0;
const common_1 = require("@nestjs/common");
let IdempotencyInterceptor = class IdempotencyInterceptor {
    intercept(context, next) {
        const req = context.switchToHttp().getRequest();
        const method = req.method;
        if (['POST', 'PATCH', 'PUT'].includes(method)) {
            const key = req.headers['idempotency-key'];
            if (!key) {
                throw new common_1.BadRequestException('Idempotency-Key header is required');
            }
        }
        return next.handle();
    }
};
exports.IdempotencyInterceptor = IdempotencyInterceptor;
exports.IdempotencyInterceptor = IdempotencyInterceptor = __decorate([
    (0, common_1.Injectable)()
], IdempotencyInterceptor);
//# sourceMappingURL=idempotency.interceptor.js.map