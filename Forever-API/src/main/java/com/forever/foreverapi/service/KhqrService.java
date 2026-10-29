package com.forever.foreverapi.service;

import com.forever.foreverapi.model.dto.OrderDtos.PlaceOrderRequest;
import com.forever.foreverapi.model.dto.PaymentDtos.KhqrCheckout;
import com.forever.foreverapi.model.dto.PaymentDtos.KhqrPaymentStatus;

public interface KhqrService {
    KhqrCheckout checkout(Long userId, PlaceOrderRequest request);
    KhqrPaymentStatus verify(Long userId, Long orderId);
    /** Gives up on the payment unless Bakong shows it was already made. */
    KhqrPaymentStatus cancel(Long userId, Long orderId);
}
