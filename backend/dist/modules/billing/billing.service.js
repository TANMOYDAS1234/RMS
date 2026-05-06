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
exports.BillingService = void 0;
const common_1 = require("@nestjs/common");
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
const bill_schema_1 = require("./bill.schema");
const orders_service_1 = require("../orders/orders.service");
let BillingService = class BillingService {
    constructor(billModel, ordersService) {
        this.billModel = billModel;
        this.ordersService = ordersService;
    }
    async generateBill(orderId, discountPercent = 0) {
        const existing = await this.billModel.findOne({ orderId: new mongoose_2.Types.ObjectId(orderId) });
        if (existing)
            return existing;
        const order = await this.ordersService.getById(orderId);
        if (!order)
            throw new common_1.NotFoundException('Order not found');
        const subtotal = order.subtotal ?? 0;
        const discountAmount = +(subtotal * (discountPercent / 100)).toFixed(2);
        const gstAmount = +((subtotal - discountAmount) * 0.18).toFixed(2);
        const total = +(subtotal - discountAmount + gstAmount).toFixed(2);
        return this.billModel.create({
            orderId: new mongoose_2.Types.ObjectId(orderId),
            tableLabel: order.tableLabel,
            subtotal,
            discountAmount,
            discountPercent,
            gstAmount,
            total,
        });
    }
    async processPayment(billId, cashierId, paymentMethod, splitPayments, idempotencyKey) {
        if (idempotencyKey) {
            const existing = await this.billModel.findOne({ _id: billId, processedKeys: idempotencyKey });
            if (existing)
                return existing;
        }
        const bill = await this.billModel.findById(billId);
        if (!bill)
            throw new common_1.NotFoundException('Bill not found');
        if (bill.isPaid)
            throw new common_1.BadRequestException('Bill already paid');
        bill.isPaid = true;
        bill.paidAt = new Date();
        bill.cashierId = cashierId;
        bill.paymentMethod = paymentMethod;
        if (splitPayments?.length)
            bill.splitPayments = splitPayments;
        if (idempotencyKey)
            bill.processedKeys.push(idempotencyKey);
        return bill.save();
    }
    async findByOrder(orderId) {
        return this.billModel.findOne({ orderId: new mongoose_2.Types.ObjectId(orderId) }).lean();
    }
    async findAll(isPaid) {
        const filter = isPaid !== undefined ? { isPaid } : {};
        return this.billModel.find(filter).sort({ createdAt: -1 }).lean();
    }
    async getDailyRevenue() {
        const start = new Date();
        start.setHours(0, 0, 0, 0);
        const result = await this.billModel.aggregate([
            { $match: { isPaid: true, paidAt: { $gte: start } } },
            { $group: { _id: null, total: { $sum: '$total' }, count: { $sum: 1 } } },
        ]);
        return result[0] ?? { total: 0, count: 0 };
    }
};
exports.BillingService = BillingService;
exports.BillingService = BillingService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(bill_schema_1.Bill.name)),
    __metadata("design:paramtypes", [mongoose_2.Model,
        orders_service_1.OrdersService])
], BillingService);
//# sourceMappingURL=billing.service.js.map