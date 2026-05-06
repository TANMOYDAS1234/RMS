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
exports.BillingController = void 0;
const common_1 = require("@nestjs/common");
const class_validator_1 = require("class-validator");
const billing_service_1 = require("./billing.service");
const bill_schema_1 = require("./bill.schema");
const jwt_auth_guard_1 = require("../../common/guards/jwt-auth.guard");
const roles_guard_1 = require("../../common/guards/roles.guard");
const roles_decorator_1 = require("../../common/decorators/roles.decorator");
class GenerateBillDto {
}
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    (0, class_validator_1.Max)(100),
    __metadata("design:type", Number)
], GenerateBillDto.prototype, "discountPercent", void 0);
class PaymentDto {
}
__decorate([
    (0, class_validator_1.IsEnum)(bill_schema_1.PaymentMethod),
    __metadata("design:type", String)
], PaymentDto.prototype, "paymentMethod", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    __metadata("design:type", Array)
], PaymentDto.prototype, "splitPayments", void 0);
let BillingController = class BillingController {
    constructor(billingService) {
        this.billingService = billingService;
    }
    findAll(isPaid) {
        return this.billingService.findAll(isPaid !== undefined ? isPaid === 'true' : undefined);
    }
    dailyRevenue() { return this.billingService.getDailyRevenue(); }
    findByOrder(orderId) { return this.billingService.findByOrder(orderId); }
    generate(orderId, dto) {
        return this.billingService.generateBill(orderId, dto.discountPercent ?? 0);
    }
    pay(id, dto, req, key) {
        return this.billingService.processPayment(id, req.user._id, dto.paymentMethod, dto.splitPayments, key);
    }
};
exports.BillingController = BillingController;
__decorate([
    (0, common_1.Get)(),
    (0, roles_decorator_1.Roles)('admin', 'manager', 'cashier'),
    __param(0, (0, common_1.Query)('isPaid')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], BillingController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)('revenue/daily'),
    (0, roles_decorator_1.Roles)('admin', 'manager'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], BillingController.prototype, "dailyRevenue", null);
__decorate([
    (0, common_1.Get)('order/:orderId'),
    (0, roles_decorator_1.Roles)('admin', 'manager', 'cashier', 'waiter'),
    __param(0, (0, common_1.Param)('orderId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], BillingController.prototype, "findByOrder", null);
__decorate([
    (0, common_1.Post)('order/:orderId/generate'),
    (0, roles_decorator_1.Roles)('admin', 'manager', 'cashier'),
    __param(0, (0, common_1.Param)('orderId')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, GenerateBillDto]),
    __metadata("design:returntype", void 0)
], BillingController.prototype, "generate", null);
__decorate([
    (0, common_1.Post)(':id/pay'),
    (0, roles_decorator_1.Roles)('admin', 'manager', 'cashier'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Request)()),
    __param(3, (0, common_1.Headers)('idempotency-key')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, PaymentDto, Object, String]),
    __metadata("design:returntype", void 0)
], BillingController.prototype, "pay", null);
exports.BillingController = BillingController = __decorate([
    (0, common_1.Controller)('billing'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    __metadata("design:paramtypes", [billing_service_1.BillingService])
], BillingController);
//# sourceMappingURL=billing.controller.js.map