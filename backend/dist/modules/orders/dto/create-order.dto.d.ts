export declare class OrderItemDto {
    itemId: string;
    name: string;
    quantity: number;
    unitPrice: number;
    notes?: string;
}
export declare class CreateOrderDto {
    tableId: string;
    tableLabel: string;
    items: OrderItemDto[];
    notes?: string;
}
