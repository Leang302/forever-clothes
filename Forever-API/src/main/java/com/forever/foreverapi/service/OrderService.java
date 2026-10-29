package com.forever.foreverapi.service;

import com.forever.foreverapi.common.response.PageResponse;
import com.forever.foreverapi.model.dto.OrderDtos.OrderResponse;
import com.forever.foreverapi.model.dto.OrderDtos.PlaceOrderRequest;
import com.forever.foreverapi.model.entity.OrderStatus;

public interface OrderService {
    OrderResponse place(Long userId, PlaceOrderRequest req);
    PageResponse<OrderResponse> mine(Long userId, int page, int size);
    OrderResponse getMine(Long userId, Long id);
    OrderResponse cancel(Long userId, Long id);
    void abortOnlinePayment(Long userId, Long id);
    PageResponse<OrderResponse> all(OrderStatus status, int page, int size);
    /** {@code reason} is required for CANCELLED (emailed to the customer) and ignored otherwise. */
    OrderResponse updateStatus(Long id, OrderStatus status, String reason);
    PageResponse<OrderResponse> forCustomer(Long userId, int page, int size);
    void confirmOnlinePayment(Long orderId);
    void recordKhqrPayment(Long orderId, String md5);
}
