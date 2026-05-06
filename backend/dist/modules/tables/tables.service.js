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
exports.TablesService = void 0;
const common_1 = require("@nestjs/common");
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
const table_schema_1 = require("./table.schema");
let TablesService = class TablesService {
    constructor(tableModel) {
        this.tableModel = tableModel;
    }
    async findAll() { return this.tableModel.find().lean(); }
    async findById(id) {
        const t = await this.tableModel.findById(id).lean();
        if (!t)
            throw new common_1.NotFoundException('Table not found');
        return t;
    }
    async create(dto) {
        const exists = await this.tableModel.findOne({ label: dto.label });
        if (exists)
            throw new common_1.ConflictException('Table label already exists');
        return this.tableModel.create(dto);
    }
    async updateStatus(id, status, activeOrderId) {
        const update = { status };
        if (activeOrderId !== undefined)
            update.activeOrderId = activeOrderId;
        if (status === table_schema_1.TableStatus.AVAILABLE)
            update.activeOrderId = null;
        const t = await this.tableModel.findByIdAndUpdate(id, update, { new: true }).lean();
        if (!t)
            throw new common_1.NotFoundException('Table not found');
        return t;
    }
    async delete(id) {
        await this.tableModel.findByIdAndDelete(id);
        return { deleted: true };
    }
};
exports.TablesService = TablesService;
exports.TablesService = TablesService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(table_schema_1.Table.name)),
    __metadata("design:paramtypes", [mongoose_2.Model])
], TablesService);
//# sourceMappingURL=tables.service.js.map