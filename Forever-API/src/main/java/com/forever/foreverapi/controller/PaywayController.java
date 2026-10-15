package com.forever.foreverapi.controller;

import com.forever.foreverapi.common.security.AuthUser;
import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.model.dto.OrderDtos.PlaceOrderRequest;
import com.forever.foreverapi.model.dto.PaymentDtos.PaywayCheckout;
import com.forever.foreverapi.model.dto.PaymentDtos.PaywayVerifyRequest;
import com.forever.foreverapi.model.dto.PaymentDtos.PaywayVerifyResponse;
import com.forever.foreverapi.service.OrderService;
import com.forever.foreverapi.service.PaywayService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/payway")
public class PaywayController {
    private final PaywayService payway;
    private final OrderService orders;
    public PaywayController(PaywayService payway, OrderService orders) { this.payway = payway; this.orders = orders; }

    @PostMapping("/checkout")
    public PaywayCheckout checkout(@AuthenticationPrincipal AuthUser user, @Valid @RequestBody PlaceOrderRequest request) {
        return payway.checkout(user.id(), request);
    }

    @PostMapping("/verify")
    public PaywayVerifyResponse verify(@AuthenticationPrincipal AuthUser user, @RequestBody PaywayVerifyRequest request) {
        return payway.verify(user.id(), request.orderId(), request.transactionId());
    }

    @PostMapping("/{orderId}/abort")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void abort(@AuthenticationPrincipal AuthUser user, @PathVariable Long orderId) {
        orders.abortOnlinePayment(user.id(), orderId);
    }

    @PostMapping("/callback")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void callback(@RequestBody Map<String, Object> body,
                         @RequestHeader(value = "X-PayWay-HMAC-SHA512", required = false) String signature) {
        if (!payway.validCallback(body, signature)) throw ApiException.unauthorized("INVALID_PAYWAY_SIGNATURE", "Invalid PayWay callback signature");
        if (!"0".equals(String.valueOf(body.get("status")))) return;
        try { orders.confirmOnlinePayment(Long.valueOf(String.valueOf(body.get("return_params")))); }
        catch (NumberFormatException e) { throw ApiException.badRequest("INVALID_TRANSACTION", "Invalid PayWay order reference"); }
    }
}
