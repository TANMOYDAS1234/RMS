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
exports.OrdersGateway = void 0;
const websockets_1 = require("@nestjs/websockets");
const socket_io_1 = require("socket.io");
let OrdersGateway = class OrdersGateway {
    constructor() {
        this.pendingAcks = new Map();
    }
    handleConnection(client) {
        const role = client.handshake.auth?.role;
        if (role)
            client.join(`role:${role}`);
    }
    handleDisconnect(client) {
    }
    emitOrderCreated(order) {
        this._emitWithAck('order:created', order);
    }
    emitOrderUpdated(order) {
        this._emitWithAck('order:updated', order);
    }
    emitKitchenProgress(data) {
        this.server.emit('kitchen:progress', data);
    }
    handleAck(data) {
        const pending = this.pendingAcks.get(data.eventId);
        if (pending) {
            clearTimeout(pending.timer);
            this.pendingAcks.delete(data.eventId);
        }
    }
    _emitWithAck(event, payload, retries = 0) {
        const eventId = `${event}:${payload._id}:${Date.now()}`;
        const enriched = { ...payload, _eventId: eventId };
        this.server.emit(event, enriched);
        if (retries < 3) {
            const timer = setTimeout(() => {
                this.pendingAcks.delete(eventId);
                this._emitWithAck(event, payload, retries + 1);
            }, 5000);
            this.pendingAcks.set(eventId, { payload, retries, timer });
        }
    }
};
exports.OrdersGateway = OrdersGateway;
__decorate([
    (0, websockets_1.WebSocketServer)(),
    __metadata("design:type", socket_io_1.Server)
], OrdersGateway.prototype, "server", void 0);
__decorate([
    (0, websockets_1.SubscribeMessage)('ack'),
    __param(0, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], OrdersGateway.prototype, "handleAck", null);
exports.OrdersGateway = OrdersGateway = __decorate([
    (0, websockets_1.WebSocketGateway)({
        cors: { origin: '*' },
        namespace: '/',
    })
], OrdersGateway);
//# sourceMappingURL=orders.gateway.js.map