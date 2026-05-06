"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrdersController = void 0;
const common_1 = require("@nestjs/common");
const orders_service_1 = require("./orders.service");
const create_order_dto_1 = require("./dto/create-order.dto");
const update_status_dto_1 = require("./dto/update-status.dto");
const jwt_auth_guard_1 = require("../../common/guards/jwt-auth.guard");
const roles_decorator_1 = require("../../common/decorators/roles.decorator");
const roles_guard_1 = require("../../common/guards/roles.guard");
let OrdersController = class OrdersController {
    constructor(ordersService) {
        this.ordersService = ordersService;
    }
    getActive() {
        return this.ordersService.getActiveOrders();
    }
    getById(id) {
        return this.ordersService.getById(id);
    }
    create(dto, req, idempotencyKey) {
        return this.ordersService.create(dto, req.user.id, idempotencyKey);
    }
    updateStatus(id, dto, req, idempotencyKey) {
        return this.ordersService.updateStatus(id, dto, req.user.id, idempotencyKey);
    }
    updateProgress(orderId, itemId, progress, req) {
        return this.ordersService.updateItemProgress(orderId, itemId, progress, req.user.id);
    }
};
exports.OrdersController = OrdersController;
__decorate([
    (0, common_1.Get)('active'),
    (0, roles_decorator_1.Roles)('admin', 'manager', 'waiter', 'chef', 'cashier'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "getActive", null);
__decorate([
    (0, common_1.Get)(':id'),
    (0, roles_decorator_1.Roles)('admin', 'manager', 'waiter', 'chef', 'cashier'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "getById", null);
__decorate([
    (0, common_1.Post)(),
    (0, roles_decorator_1.Roles)('admin', 'manager', 'waiter', 'customer'),
    (0, common_1.HttpCode)(common_1.HttpStatus.CREATED),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Request)()),
    __param(2, (0, common_1.Headers)('idempotency-key')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_order_dto_1.CreateOrderDto, Object, String]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "create", null);
__decorate([
    (0, common_1.Patch)(':id/status'),
    (0, roles_decorator_1.Roles)('admin', 'manager', 'waiter', 'chef', 'cashier'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Request)()),
    __param(3, (0, common_1.Headers)('idempotency-key')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_status_dto_1.UpdateStatusDto, Object, String]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "updateStatus", null);
__decorate([
    (0, common_1.Patch)(':id/items/:itemId/progress'),
    (0, roles_decorator_1.Roles)('chef'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Param)('itemId')),
    __param(2, (0, common_1.Body)('progress')),
    __param(3, (0, common_1.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, Number, Object]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "updateProgress", null);
exports.OrdersController = OrdersController = __decorate([
    (0, common_1.Controller)('orders'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    __metadata("design:paramtypes", [orders_service_1.OrdersService])
], OrdersController);
//# sourceMappingURL=orders.controller.js.map