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
exports.OrdersService = void 0;
const common_1 = require("@nestjs/common");
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
const order_schema_1 = require("./order.schema");
const orders_gateway_1 = require("../../gateways/orders.gateway");
const TRANSITIONS = {
    [order_schema_1.OrderStatus.CREATED]: [order_schema_1.OrderStatus.CONFIRMED],
    [order_schema_1.OrderStatus.CONFIRMED]: [order_schema_1.OrderStatus.PREPARING],
    [order_schema_1.OrderStatus.PREPARING]: [order_schema_1.OrderStatus.READY],
    [order_schema_1.OrderStatus.READY]: [order_schema_1.OrderStatus.SERVED],
    [order_schema_1.OrderStatus.SERVED]: [order_schema_1.OrderStatus.BILLED],
    [order_schema_1.OrderStatus.BILLED]: [order_schema_1.OrderStatus.PAID],
    [order_schema_1.OrderStatus.PAID]: [order_schema_1.OrderStatus.CLOSED],
};
let OrdersService = class OrdersService {
    constructor(orderModel, gateway) {
        this.orderModel = orderModel;
        this.gateway = gateway;
    }
    async create(dto, userId, idempotencyKey) {
        const existing = await this.orderModel.findOne({
            processedKeys: idempotencyKey,
        });
        if (existing)
            return existing;
        const subtotal = dto.items.reduce((sum, i) => sum + i.unitPrice * i.quantity, 0);
        const gstAmount = +(subtotal * 0.18).toFixed(2);
        const total = +(subtotal + gstAmount).toFixed(2);
        const order = await this.orderModel.create({
            ...dto,
            waiterId: userId,
            subtotal,
            gstAmount,
            total,
            processedKeys: [idempotencyKey],
            auditLog: [{ action: 'CREATED', by: userId, at: new Date() }],
        });
        this.gateway.emitOrderCreated(order);
        return order;
    }
    async getActiveOrders() {
        return this.orderModel
            .find({
            status: {
                $nin: [order_schema_1.OrderStatus.PAID, order_schema_1.OrderStatus.CLOSED],
            },
        })
            .sort({ createdAt: -1 })
            .lean();
    }
    async getById(id) {
        const order = await this.orderModel.findById(id).lean();
        if (!order)
            throw new common_1.NotFoundException(`Order ${id} not found`);
        return order;
    }
    async updateStatus(id, dto, userId, idempotencyKey) {
        const existing = await this.orderModel.findOne({
            _id: id,
            processedKeys: idempotencyKey,
        });
        if (existing)
            return existing;
        const session = await this.orderModel.db.startSession();
        session.startTransaction();
        try {
            const order = await this.orderModel
                .findById(id)
                .session(session);
            if (!order)
                throw new common_1.NotFoundException(`Order ${id} not found`);
            if (order.version !== dto.version) {
                throw new common_1.ConflictException({
                    message: 'Version conflict. Order was modified by another user.',
                    serverVersion: order.version,
                    serverStatus: order.status,
                });
            }
            const allowed = TRANSITIONS[order.status] ?? [];
            if (!allowed.includes(dto.status)) {
                throw new common_1.BadRequestException(`Cannot transition from ${order.status} to ${dto.status}`);
            }
            order.status = dto.status;
            order.processedKeys.push(idempotencyKey);
            order.auditLog.push({ action: `STATUS_${dto.status.toUpperCase()}`, by: userId, at: new Date() });
            await order.save({ session });
            await session.commitTransaction();
            this.gateway.emitOrderUpdated(order);
            return order;
        }
        catch (err) {
            await session.abortTransaction();
            throw err;
        }
        finally {
            session.endSession();
        }
    }
    async updateItemProgress(orderId, itemId, progress, userId) {
        await this.orderModel.updateOne({ _id: orderId, 'items.itemId': itemId }, { $set: { 'items.$.progress': progress } });
        this.gateway.emitKitchenProgress({ orderId, itemId, progress });
    }
};
exports.OrdersService = OrdersService;
exports.OrdersService = OrdersService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(order_schema_1.Order.name)),
    __metadata("design:paramtypes", [mongoose_2.Model,
        orders_gateway_1.OrdersGateway])
], OrdersService);
//# sourceMappingURL=orders.service.js.map