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
exports.InventoryController = void 0;
const common_1 = require("@nestjs/common");
const class_validator_1 = require("class-validator");
const inventory_service_1 = require("./inventory.service");
const jwt_auth_guard_1 = require("../../common/guards/jwt-auth.guard");
const roles_guard_1 = require("../../common/guards/roles.guard");
const roles_decorator_1 = require("../../common/decorators/roles.decorator");
class CreateIngredientDto {
}
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateIngredientDto.prototype, "name", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateIngredientDto.prototype, "unit", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], CreateIngredientDto.prototype, "currentStock", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], CreateIngredientDto.prototype, "lowStockThreshold", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    __metadata("design:type", Number)
], CreateIngredientDto.prototype, "costPerUnit", void 0);
class AdjustStockDto {
}
__decorate([
    (0, class_validator_1.IsNumber)(),
    __metadata("design:type", Number)
], AdjustStockDto.prototype, "delta", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], AdjustStockDto.prototype, "reason", void 0);
let InventoryController = class InventoryController {
    constructor(inventoryService) {
        this.inventoryService = inventoryService;
    }
    findAll() { return this.inventoryService.findAll(); }
    lowStock() { return this.inventoryService.findLowStock(); }
    findOne(id) { return this.inventoryService.findById(id); }
    create(dto) { return this.inventoryService.create(dto); }
    adjust(id, dto, req) {
        return this.inventoryService.adjustStock(id, dto.delta, dto.reason, req.user._id);
    }
    update(id, dto) {
        return this.inventoryService.update(id, dto);
    }
    delete(id) { return this.inventoryService.delete(id); }
};
exports.InventoryController = InventoryController;
__decorate([
    (0, common_1.Get)(),
    (0, roles_decorator_1.Roles)('admin', 'manager', 'chef'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], InventoryController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)('low-stock'),
    (0, roles_decorator_1.Roles)('admin', 'manager', 'chef'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], InventoryController.prototype, "lowStock", null);
__decorate([
    (0, common_1.Get)(':id'),
    (0, roles_decorator_1.Roles)('admin', 'manager', 'chef'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], InventoryController.prototype, "findOne", null);
__decorate([
    (0, common_1.Post)(),
    (0, roles_decorator_1.Roles)('admin', 'manager'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [CreateIngredientDto]),
    __metadata("design:returntype", void 0)
], InventoryController.prototype, "create", null);
__decorate([
    (0, common_1.Patch)(':id/adjust'),
    (0, roles_decorator_1.Roles)('admin', 'manager', 'chef'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, AdjustStockDto, Object]),
    __metadata("design:returntype", void 0)
], InventoryController.prototype, "adjust", null);
__decorate([
    (0, common_1.Patch)(':id'),
    (0, roles_decorator_1.Roles)('admin', 'manager'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], InventoryController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':id'),
    (0, roles_decorator_1.Roles)('admin'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], InventoryController.prototype, "delete", null);
exports.InventoryController = InventoryController = __decorate([
    (0, common_1.Controller)('inventory'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    __metadata("design:paramtypes", [inventory_service_1.InventoryService])
], InventoryController);
//# sourceMappingURL=inventory.controller.js.map