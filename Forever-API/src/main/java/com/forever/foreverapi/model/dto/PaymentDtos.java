package com.forever.foreverapi.model.dto;

public final class PaymentDtos {
    private PaymentDtos() {}
    public record PaywayCheckout(Long orderId, String transactionId, String qrImage, String qrString,
                                 String deeplink) {}
    public record PaywayVerifyRequest(Long orderId, String transactionId) {}
    public record PaywayVerifyResponse(boolean paid, String status) {}
}
