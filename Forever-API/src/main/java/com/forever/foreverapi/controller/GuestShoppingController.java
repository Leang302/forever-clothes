package com.forever.foreverapi.controller;

import com.forever.foreverapi.config.GuestSessionFilter;
import com.forever.foreverapi.model.dto.OrderDtos.OrderResponse;
import com.forever.foreverapi.model.dto.PaymentDtos.KhqrPaymentStatus;
import com.forever.foreverapi.service.GuestSessionLimiter;
import com.forever.foreverapi.service.GuestSessionService;
import com.forever.foreverapi.service.KhqrService;
import com.forever.foreverapi.service.OrderService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;

/**
 * Anonymous shopping. A guest cart session is NOT a login: it only reaches the cart and checkout (send it as
 * X-Guest-Session). A guest order is opened with its own order-access token (X-Order-Access), which only the
 * checkout response hands out — never by guessing an id, and never via an account.
 */
@RestController
@Tag(name = "Guest shopping", description = "Anonymous cart sessions and access to a guest's own order")
@SecurityRequirements
public class GuestShoppingController {

    public static final String ORDER_ACCESS_HEADER = "X-Order-Access";

    public record GuestSessionResponse(String token, Instant expiresAt) {
    }

    private final GuestSessionService sessions;
    private final GuestSessionLimiter limiter;
    private final OrderService orders;
    private final KhqrService khqr;

    public GuestShoppingController(GuestSessionService sessions, GuestSessionLimiter limiter, OrderService orders,
                                   KhqrService khqr) {
        this.sessions = sessions;
        this.limiter = limiter;
        this.orders = orders;
        this.khqr = khqr;
    }

    @Operation(summary = "Start an anonymous cart session",
            description = "Returns an opaque token to send as X-Guest-Session on /api/cart/** and checkout. "
                    + "Idle sessions expire (see expiresAt; it slides forward on use, up to a maximum lifetime).")
    @PostMapping("/api/guest-sessions")
    @ResponseStatus(HttpStatus.CREATED)
    public GuestSessionResponse start(HttpServletRequest request) {
        limiter.acquire(request.getRemoteAddr());
        var issued = sessions.create();
        return new GuestSessionResponse(issued.token(), issued.expiresAt());
    }

    @Operation(summary = "End the current guest session now (its cart is discarded; orders are kept)")
    @DeleteMapping("/api/guest-sessions/current")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void end(@RequestHeader(GuestSessionFilter.HEADER) String token) {
        sessions.revoke(token);
    }

    @Operation(summary = "A guest's own order (confirmation)", description = "Requires the order's X-Order-Access token.")
    @GetMapping("/api/guest-orders/{id}")
    public OrderResponse order(@PathVariable Long id, @RequestHeader(value = ORDER_ACCESS_HEADER, required = false) String access) {
        return orders.getAsGuest(id, access);
    }

    @Operation(summary = "Cancel a guest's own order while it is still cancellable")
    @PostMapping("/api/guest-orders/{id}/cancel")
    public OrderResponse cancel(@PathVariable Long id, @RequestHeader(value = ORDER_ACCESS_HEADER, required = false) String access) {
        return orders.cancelAsGuest(id, access);
    }

    @Operation(summary = "Check a guest's KHQR payment with Bakong")
    @PostMapping("/api/guest-orders/{id}/khqr/verify")
    public KhqrPaymentStatus verify(@PathVariable Long id, @RequestHeader(value = ORDER_ACCESS_HEADER, required = false) String access) {
        return khqr.verifyAsGuest(id, access);
    }

    @Operation(summary = "Give up a guest's unpaid KHQR payment (unless Bakong shows it was paid)")
    @PostMapping("/api/guest-orders/{id}/khqr/cancel")
    public KhqrPaymentStatus cancelPayment(@PathVariable Long id, @RequestHeader(value = ORDER_ACCESS_HEADER, required = false) String access) {
        return khqr.cancelAsGuest(id, access);
    }
}
