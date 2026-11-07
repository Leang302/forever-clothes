package com.forever.foreverapi.service;

import com.forever.foreverapi.common.security.ShopperRef;
import com.forever.foreverapi.model.dto.OrderDtos.PlaceOrderRequest;
import com.forever.foreverapi.model.dto.PaymentDtos.KhqrCheckout;
import com.forever.foreverapi.model.dto.PaymentDtos.KhqrPaymentStatus;

public interface KhqrService {
    KhqrCheckout checkout(ShopperRef shopper, PlaceOrderRequest request);
    KhqrPaymentStatus verify(Long userId, Long orderId);
    /** Gives up on the payment unless Bakong shows it was already made. */
    KhqrPaymentStatus cancel(Long userId, Long orderId);
    /** Guest variants: only for the order whose access token is presented. */
    KhqrPaymentStatus verifyAsGuest(Long orderId, String accessToken);
    KhqrPaymentStatus cancelAsGuest(Long orderId, String accessToken);
}
