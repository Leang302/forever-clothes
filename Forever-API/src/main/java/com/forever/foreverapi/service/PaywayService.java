package com.forever.foreverapi.service;

import com.forever.foreverapi.model.dto.OrderDtos.PlaceOrderRequest;
import com.forever.foreverapi.model.dto.PaymentDtos.PaywayCheckout;
import com.forever.foreverapi.model.dto.PaymentDtos.PaywayVerifyResponse;
import java.util.Map;

public interface PaywayService {
    PaywayCheckout checkout(Long userId, PlaceOrderRequest request);
    PaywayVerifyResponse verify(Long userId, Long orderId, String transactionId);
    boolean validCallback(Map<String, Object> body, String signature);
}
