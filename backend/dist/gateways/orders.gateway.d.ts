import { OnGatewayConnection, OnGatewayDisconnect } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
export declare class OrdersGateway implements OnGatewayConnection, OnGatewayDisconnect {
    server: Server;
    private pendingAcks;
    handleConnection(client: Socket): void;
    handleDisconnect(client: Socket): void;
    emitOrderCreated(order: any): void;
    emitOrderUpdated(order: any): void;
    emitKitchenProgress(data: {
        orderId: string;
        itemId: string;
        progress: number;
    }): void;
    handleAck(data: {
        eventId: string;
    }): void;
    private _emitWithAck;
}
