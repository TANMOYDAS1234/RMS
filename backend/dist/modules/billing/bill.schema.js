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
exports.BillSchema = exports.Bill = exports.PaymentMethod = void 0;
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
var PaymentMethod;
(function (PaymentMethod) {
    PaymentMethod["CASH"] = "cash";
    PaymentMethod["CARD"] = "card";
    PaymentMethod["UPI"] = "upi";
    PaymentMethod["SPLIT"] = "split";
})(PaymentMethod || (exports.PaymentMethod = PaymentMethod = {}));
let SplitPayment = class SplitPayment {
};
__decorate([
    (0, mongoose_1.Prop)({ enum: PaymentMethod }),
    __metadata("design:type", String)
], SplitPayment.prototype, "method", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", Number)
], SplitPayment.prototype, "amount", void 0);
SplitPayment = __decorate([
    (0, mongoose_1.Schema)({ _id: false })
], SplitPayment);
let Bill = class Bill {
};
exports.Bill = Bill;
__decorate([
    (0, mongoose_1.Prop)({ required: true, type: mongoose_2.Types.ObjectId, ref: 'Order' }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], Bill.prototype, "orderId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], Bill.prototype, "tableLabel", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", Number)
], Bill.prototype, "subtotal", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 0 }),
    __metadata("design:type", Number)
], Bill.prototype, "discountAmount", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 0 }),
    __metadata("design:type", Number)
], Bill.prototype, "discountPercent", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", Number)
], Bill.prototype, "gstAmount", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", Number)
], Bill.prototype, "total", void 0);
__decorate([
    (0, mongoose_1.Prop)({ enum: PaymentMethod }),
    __metadata("design:type", String)
], Bill.prototype, "paymentMethod", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: [SplitPayment], default: [] }),
    __metadata("design:type", Array)
], Bill.prototype, "splitPayments", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: false }),
    __metadata("design:type", Boolean)
], Bill.prototype, "isPaid", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", Date)
], Bill.prototype, "paidAt", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", String)
], Bill.prototype, "cashierId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: [String], default: [] }),
    __metadata("design:type", Array)
], Bill.prototype, "processedKeys", void 0);
exports.Bill = Bill = __decorate([
    (0, mongoose_1.Schema)({ timestamps: true })
], Bill);
exports.BillSchema = mongoose_1.SchemaFactory.createForClass(Bill);
exports.BillSchema.index({ orderId: 1 });
exports.BillSchema.index({ isPaid: 1, createdAt: -1 });
//# sourceMappingURL=bill.schema.js.map