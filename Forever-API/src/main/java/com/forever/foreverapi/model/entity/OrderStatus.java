package com.forever.foreverapi.model.entity;

import java.util.List;

public enum OrderStatus {
    PAYMENT_PENDING, ORDER_PLACED, PACKING, SHIPPED, OUT_FOR_DELIVERY, DELIVERED, CANCELLED;

    /**
     * Statuses an admin may move an order to from this one: one step forward, or cancel before it ships.
     * An unpaid online order can only be cancelled; delivered and cancelled orders are final.
     */
    public List<OrderStatus> next() {
        return switch (this) {
            case PAYMENT_PENDING -> List.of(CANCELLED);
            case ORDER_PLACED -> List.of(PACKING, CANCELLED);
            case PACKING -> List.of(SHIPPED, CANCELLED);
            case SHIPPED -> List.of(OUT_FOR_DELIVERY);
            case OUT_FOR_DELIVERY -> List.of(DELIVERED);
            case DELIVERED, CANCELLED -> List.of();
        };
    }
}
