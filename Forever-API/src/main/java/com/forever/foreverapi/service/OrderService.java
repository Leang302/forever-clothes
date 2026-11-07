package com.forever.foreverapi.service;

import com.forever.foreverapi.common.response.PageResponse;
import com.forever.foreverapi.common.security.ShopperRef;
import com.forever.foreverapi.model.dto.OrderDtos.OrderResponse;
import com.forever.foreverapi.model.dto.OrderDtos.PlaceOrderRequest;
import com.forever.foreverapi.model.entity.OrderStatus;

public interface OrderService {
    /** Places an order from [shopper]'s own cart. A guest order belongs to no account and carries an access token. */
    OrderResponse place(ShopperRef shopper, PlaceOrderRequest req);
    PageResponse<OrderResponse> mine(Long userId, int page, int size);
    OrderResponse getMine(Long userId, Long id);
    OrderResponse cancel(Long userId, Long id);
    void abortOnlinePayment(Long userId, Long id);

    // A guest reaches only the order whose access token it holds; anything else is "not found".
    OrderResponse getAsGuest(Long id, String accessToken);
    OrderResponse cancelAsGuest(Long id, String accessToken);
    void abortOnlinePaymentAsGuest(Long id, String accessToken);
    /** Throws 404 unless [accessToken] opens guest order [id]. */
    void requireGuestAccess(Long id, String accessToken);

    PageResponse<OrderResponse> all(OrderStatus status, int page, int size);
    /** {@code reason} is required for CANCELLED (emailed to the customer) and ignored otherwise. */
    OrderResponse updateStatus(Long id, OrderStatus status, String reason);
    PageResponse<OrderResponse> forCustomer(Long userId, int page, int size);
    void confirmOnlinePayment(Long orderId);
    /** Stores the QR shown to the customer unless a still-payable one is already stored (first writer wins). */
    void recordKhqrPayment(Long orderId, String md5, String qr, java.time.Instant expiresAt);
}
