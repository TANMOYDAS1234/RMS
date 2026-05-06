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
exports.OrderSchema = exports.Order = exports.OrderItem = exports.OrderStatus = void 0;
const mongoose_1 = require("@nestjs/mongoose");
var OrderStatus;
(function (OrderStatus) {
    OrderStatus["CREATED"] = "created";
    OrderStatus["CONFIRMED"] = "confirmed";
    OrderStatus["PREPARING"] = "preparing";
    OrderStatus["READY"] = "ready";
    OrderStatus["SERVED"] = "served";
    OrderStatus["BILLED"] = "billed";
    OrderStatus["PAID"] = "paid";
    OrderStatus["CLOSED"] = "closed";
})(OrderStatus || (exports.OrderStatus = OrderStatus = {}));
let OrderItem = class OrderItem {
};
exports.OrderItem = OrderItem;
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], OrderItem.prototype, "itemId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], OrderItem.prototype, "name", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", Number)
], OrderItem.prototype, "quantity", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", Number)
], OrderItem.prototype, "unitPrice", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 0, min: 0, max: 1 }),
    __metadata("design:type", Number)
], OrderItem.prototype, "progress", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", String)
], OrderItem.prototype, "notes", void 0);
exports.OrderItem = OrderItem = __decorate([
    (0, mongoose_1.Schema)({ _id: false })
], OrderItem);
const OrderItemSchema = mongoose_1.SchemaFactory.createForClass(OrderItem);
let Order = class Order {
};
exports.Order = Order;
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], Order.prototype, "tableId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], Order.prototype, "tableLabel", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: [OrderItemSchema], default: [] }),
    __metadata("design:type", Array)
], Order.prototype, "items", void 0);
__decorate([
    (0, mongoose_1.Prop)({ enum: OrderStatus, default: OrderStatus.CREATED }),
    __metadata("design:type", String)
], Order.prototype, "status", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 1 }),
    __metadata("design:type", Number)
], Order.prototype, "version", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: [String], default: [] }),
    __metadata("design:type", Array)
], Order.prototype, "processedKeys", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", String)
], Order.prototype, "waiterId", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", String)
], Order.prototype, "notes", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 0 }),
    __metadata("design:type", Number)
], Order.prototype, "subtotal", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 0 }),
    __metadata("design:type", Number)
], Order.prototype, "gstAmount", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 0 }),
    __metadata("design:type", Number)
], Order.prototype, "discountAmount", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 0 }),
    __metadata("design:type", Number)
], Order.prototype, "total", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: [{ action: String, by: String, at: Date, meta: Object }], default: [] }),
    __metadata("design:type", Array)
], Order.prototype, "auditLog", void 0);
exports.Order = Order = __decorate([
    (0, mongoose_1.Schema)({ timestamps: true, optimisticConcurrency: true })
], Order);
exports.OrderSchema = mongoose_1.SchemaFactory.createForClass(Order);
exports.OrderSchema.pre('save', function (next) {
    if (this.isModified() && !this.isNew) {
        this.version += 1;
    }
    next();
});
exports.OrderSchema.index({ status: 1, createdAt: -1 });
exports.OrderSchema.index({ tableId: 1, status: 1 });
exports.OrderSchema.index({ 'processedKeys': 1 });
//# sourceMappingURL=order.schema.js.map