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
Object.defineProperty(exports, "__esModule", { value: true });
exports.TableSchema = exports.Table = exports.TableStatus = void 0;
const mongoose_1 = require("@nestjs/mongoose");
var TableStatus;
(function (TableStatus) {
    TableStatus["AVAILABLE"] = "available";
    TableStatus["OCCUPIED"] = "occupied";
    TableStatus["RESERVED"] = "reserved";
    TableStatus["CLEANING"] = "cleaning";
})(TableStatus || (exports.TableStatus = TableStatus = {}));
let Table = class Table {
};
exports.Table = Table;
__decorate([
    (0, mongoose_1.Prop)({ required: true, unique: true }),
    __metadata("design:type", String)
], Table.prototype, "label", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true, min: 1 }),
    __metadata("design:type", Number)
], Table.prototype, "capacity", void 0);
__decorate([
    (0, mongoose_1.Prop)({ enum: TableStatus, default: TableStatus.AVAILABLE }),
    __metadata("design:type", String)
], Table.prototype, "status", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", String)
], Table.prototype, "activeOrderId", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", String)
], Table.prototype, "qrCode", void 0);
exports.Table = Table = __decorate([
    (0, mongoose_1.Schema)({ timestamps: true })
], Table);
exports.TableSchema = mongoose_1.SchemaFactory.createForClass(Table);
exports.TableSchema.index({ status: 1 });
//# sourceMappingURL=table.schema.js.map