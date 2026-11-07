package com.forever.foreverapi.model.dto;

import java.math.BigDecimal;
import java.time.Instant;

public final class PaymentDtos {
    private PaymentDtos() {}
    /** [qrImage] is a PNG data URL of [qrString]; the QR stops being payable at [expiresAt]. */
    /** [guestAccessToken]: set only for a guest checkout — send as X-Order-Access to /api/guest-orders/{id}/khqr/... */
    public record KhqrCheckout(Long orderId, String qrString, String qrImage, BigDecimal amount, String currency,
                               String merchantName, Instant expiresAt, String guestAccessToken) {}
    /** [status] is PENDING, PAID or CANCELLED. A cancelled order can still be [paid] if the payment landed late. */
    public record KhqrPaymentStatus(boolean paid, String status) {}
}
