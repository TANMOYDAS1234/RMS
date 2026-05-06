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
exports.TablesController = void 0;
const common_1 = require("@nestjs/common");
const class_validator_1 = require("class-validator");
const tables_service_1 = require("./tables.service");
const table_schema_1 = require("./table.schema");
const jwt_auth_guard_1 = require("../../common/guards/jwt-auth.guard");
const roles_guard_1 = require("../../common/guards/roles.guard");
const roles_decorator_1 = require("../../common/decorators/roles.decorator");
class CreateTableDto {
}
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateTableDto.prototype, "label", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(1),
    __metadata("design:type", Number)
], CreateTableDto.prototype, "capacity", void 0);
class UpdateTableStatusDto {
}
__decorate([
    (0, class_validator_1.IsEnum)(table_schema_1.TableStatus),
    __metadata("design:type", String)
], UpdateTableStatusDto.prototype, "status", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateTableStatusDto.prototype, "activeOrderId", void 0);
let TablesController = class TablesController {
    constructor(tablesService) {
        this.tablesService = tablesService;
    }
    findAll() { return this.tablesService.findAll(); }
    findOne(id) { return this.tablesService.findById(id); }
    create(dto) { return this.tablesService.create(dto); }
    updateStatus(id, dto) {
        return this.tablesService.updateStatus(id, dto.status, dto.activeOrderId);
    }
    delete(id) { return this.tablesService.delete(id); }
};
exports.TablesController = TablesController;
__decorate([
    (0, common_1.Get)(),
    (0, roles_decorator_1.Roles)('admin', 'manager', 'waiter', 'cashier'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], TablesController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)(':id'),
    (0, roles_decorator_1.Roles)('admin', 'manager', 'waiter', 'cashier'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TablesController.prototype, "findOne", null);
__decorate([
    (0, common_1.Post)(),
    (0, roles_decorator_1.Roles)('admin', 'manager'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [CreateTableDto]),
    __metadata("design:returntype", void 0)
], TablesController.prototype, "create", null);
__decorate([
    (0, common_1.Patch)(':id/status'),
    (0, roles_decorator_1.Roles)('admin', 'manager', 'waiter'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, UpdateTableStatusDto]),
    __metadata("design:returntype", void 0)
], TablesController.prototype, "updateStatus", null);
__decorate([
    (0, common_1.Delete)(':id'),
    (0, roles_decorator_1.Roles)('admin'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TablesController.prototype, "delete", null);
exports.TablesController = TablesController = __decorate([
    (0, common_1.Controller)('tables'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    __metadata("design:paramtypes", [tables_service_1.TablesService])
], TablesController);
//# sourceMappingURL=tables.controller.js.map