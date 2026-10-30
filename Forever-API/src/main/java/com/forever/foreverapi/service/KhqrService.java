package com.forever.foreverapi.service;

import com.forever.foreverapi.model.dto.OrderDtos.PlaceOrderRequest;
import com.forever.foreverapi.model.dto.PaymentDtos.KhqrCheckout;
import com.forever.foreverapi.model.dto.PaymentDtos.KhqrPaymentStatus;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

public interface KhqrService {
    KhqrCheckout checkout(Long userId, PlaceOrderRequest request);
    KhqrPaymentStatus verify(Long userId, Long orderId);
    /** Gives up on the payment unless Bakong shows it was already made. */
    KhqrPaymentStatus cancel(Long userId, Long orderId);
    /** Open an SSE stream; the server pushes a "paid" event when payment is confirmed. */
    SseEmitter events(Long userId, Long orderId);
    /** Called by the scheduler: checks Bakong (or auto-confirms in test mode) and notifies SSE. */
    void checkAndConfirmIfPaid(com.forever.foreverapi.model.entity.Order order);
}
