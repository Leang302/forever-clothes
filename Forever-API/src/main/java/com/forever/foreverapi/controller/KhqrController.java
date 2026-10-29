package com.forever.foreverapi.controller;

import com.forever.foreverapi.common.security.AuthUser;
import com.forever.foreverapi.model.dto.OrderDtos.PlaceOrderRequest;
import com.forever.foreverapi.model.dto.PaymentDtos.KhqrCheckout;
import com.forever.foreverapi.model.dto.PaymentDtos.KhqrPaymentStatus;
import com.forever.foreverapi.service.KhqrService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/** Bakong KHQR has no payment callback, so the client polls verify until the payment shows up. */
@RestController
@RequestMapping("/api/khqr")
public class KhqrController {
    private final KhqrService khqr;
    public KhqrController(KhqrService khqr) { this.khqr = khqr; }

    @PostMapping("/checkout")
    public KhqrCheckout checkout(@AuthenticationPrincipal AuthUser user, @Valid @RequestBody PlaceOrderRequest request) {
        return khqr.checkout(user.id(), request);
    }

    @PostMapping("/{orderId}/verify")
    public KhqrPaymentStatus verify(@AuthenticationPrincipal AuthUser user, @PathVariable Long orderId) {
        return khqr.verify(user.id(), orderId);
    }

    @PostMapping("/{orderId}/cancel")
    public KhqrPaymentStatus cancel(@AuthenticationPrincipal AuthUser user, @PathVariable Long orderId) {
        return khqr.cancel(user.id(), orderId);
    }
}
