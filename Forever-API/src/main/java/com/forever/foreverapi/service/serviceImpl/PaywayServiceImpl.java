package com.forever.foreverapi.service.serviceImpl;

import com.forever.foreverapi.config.AppProperties;
import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.model.dto.OrderDtos.OrderResponse;
import com.forever.foreverapi.model.dto.OrderDtos.PlaceOrderRequest;
import com.forever.foreverapi.model.dto.PaymentDtos.PaywayCheckout;
import com.forever.foreverapi.model.dto.PaymentDtos.PaywayVerifyResponse;
import com.forever.foreverapi.service.PaywayService;
import com.forever.foreverapi.service.OrderService;
import okhttp3.MediaType;
import okhttp3.MultipartBody;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import tools.jackson.databind.json.JsonMapper;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.TreeMap;

@Service
public class PaywayServiceImpl implements PaywayService {
    private static final Logger log = LoggerFactory.getLogger(PaywayServiceImpl.class);
    private static final DateTimeFormatter REQUEST_TIME = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");
    private final AppProperties.Payway config;
    private final JsonMapper json;
    private final OrderService orders;
    private final OkHttpClient http = new OkHttpClient();
    public PaywayServiceImpl(AppProperties props, JsonMapper json, OrderService orders) {
        this.config = props.payway(); this.json = json; this.orders = orders;
    }

    public PaywayCheckout checkout(Long userId, PlaceOrderRequest request) {
        requireConfigured();
        OrderResponse order = orders.place(userId, request);
        String requestTime = LocalDateTime.now(ZoneOffset.UTC).format(REQUEST_TIME);
        String transactionId = requestTime + String.format("%06d", order.id() % 1_000_000);
        String items = encodeItems(order);
        String shipping = order.deliveryFee().toPlainString();
        // PayWay charges amount + shipping, so amount must exclude the delivery fee already in the total.
        String amount = order.total().subtract(order.deliveryFee()).toPlainString();
        String returnUrl = encodeUrl(config.callbackUrl());
        String returnParams = order.id().toString();

        var fields = new LinkedHashMap<String, String>();
        fields.put("req_time", requestTime);
        fields.put("merchant_id", config.merchantId());
        fields.put("tran_id", transactionId);
        fields.put("firstname", order.address().firstName());
        fields.put("lastname", order.address().lastName());
        fields.put("email", order.address().email());
        fields.put("phone", order.address().phone());
        fields.put("type", "purchase");
        fields.put("payment_option", "abapay");
        fields.put("items", items);
        fields.put("shipping", shipping);
        fields.put("amount", amount);
        fields.put("currency", "USD");
        if (!returnUrl.isBlank()) fields.put("return_url", returnUrl);
        fields.put("cancel_url", config.cancelUrl());
        fields.put("skip_success_page", "1");
        fields.put("continue_success_url", config.successUrl() + "/" + order.id());
        fields.put("return_params", returnParams);
        fields.put("view_type", "popup");

        // PayWay requires this exact concatenation order. It is not the form-field order.
        String valueToSign = requestTime + config.merchantId() + transactionId + amount + items + shipping
                + order.address().firstName() + order.address().lastName() + order.address().email()
                + order.address().phone() + "purchase" + "abapay" + returnUrl + config.cancelUrl()
                + config.successUrl() + "/" + order.id()
                + "" // return_deeplink
                + "USD"
                + "" // custom_fields
                + returnParams
                + "" // payout
                + "" // lifetime
                + "" // additional_params
                + "" // google_pay_token
                + "1"; // skip_success_page
        fields.put("hash", sign(valueToSign));
        try {
            var multipart = new MultipartBody.Builder().setType(MultipartBody.FORM);
            fields.forEach(multipart::addFormDataPart);
            var paywayRequest = new Request.Builder().url(config.purchaseUrl()).post(multipart.build()).build();
            try (var response = http.newCall(paywayRequest).execute()) {
                if (!response.isSuccessful() || response.body() == null) {
                    throw new IllegalStateException("PayWay returned HTTP " + response.code());
                }
                @SuppressWarnings("unchecked")
                Map<String, Object> result = json.readValue(response.body().string(), Map.class);
                @SuppressWarnings("unchecked")
                Map<String, Object> status = result.get("status") instanceof Map<?, ?> map
                        ? (Map<String, Object>) map : Map.of();
                String qrImage = stringValue(result, "qrImage", "qr_image");
                String qrString = stringValue(result, "qrString", "qr_string");
                String deeplink = stringValue(result, "abapay_deeplink", "abapayDeeplink");
                if (!"00".equals(String.valueOf(status.get("code"))) || qrImage.isBlank()) {
                    throw new IllegalStateException(String.valueOf(status.getOrDefault("message", "PayWay did not return a QR code")));
                }
                return new PaywayCheckout(order.id(), transactionId, qrImage, qrString, deeplink);
            }
        } catch (Exception e) {
            log.warn("PayWay checkout failed for order {}: {}", order.id(), e.toString());
            orders.abortOnlinePayment(userId, order.id());
            throw ApiException.unavailable("PAYWAY_UNAVAILABLE", "ABA PayWay could not create the payment QR");
        }
    }

    private static String stringValue(Map<String, Object> values, String... keys) {
        for (String key : keys) {
            Object value = values.get(key);
            if (value != null) return String.valueOf(value);
        }
        return "";
    }

    public PaywayVerifyResponse verify(Long userId, Long orderId, String transactionId) {
        requireConfigured();
        OrderResponse order = orders.getMine(userId, orderId);
        if (order.paid()) return new PaywayVerifyResponse(true, "APPROVED");
        if (transactionId == null || !transactionId.matches("\\d{20}") || !transactionId.endsWith(String.format("%06d", orderId % 1_000_000))) {
            throw ApiException.badRequest("INVALID_TRANSACTION", "Invalid PayWay transaction reference");
        }

        String requestTime = LocalDateTime.now(ZoneOffset.UTC).format(REQUEST_TIME);
        var payload = Map.of(
                "req_time", requestTime,
                "merchant_id", config.merchantId(),
                "tran_id", transactionId,
                "hash", sign(requestTime + config.merchantId() + transactionId));
        var body = RequestBody.create(json.writeValueAsString(payload), MediaType.get("application/json"));
        var request = new Request.Builder().url(config.checkUrl()).post(body).build();
        try (var response = http.newCall(request).execute()) {
            if (!response.isSuccessful() || response.body() == null) {
                throw ApiException.unavailable("PAYWAY_UNAVAILABLE", "Unable to verify ABA PayWay payment");
            }
            @SuppressWarnings("unchecked")
            Map<String, Object> result = json.readValue(response.body().string(), Map.class);
            @SuppressWarnings("unchecked")
            Map<String, Object> data = result.get("data") instanceof Map<?, ?> map ? (Map<String, Object>) map : Map.of();
            String status = String.valueOf(data.getOrDefault("payment_status", "PENDING"));
            boolean paid = "APPROVED".equalsIgnoreCase(status)
                    || "0".equals(String.valueOf(data.get("payment_status_code")));
            if (paid) orders.confirmOnlinePayment(orderId);
            return new PaywayVerifyResponse(paid, status);
        } catch (java.io.IOException e) {
            throw ApiException.unavailable("PAYWAY_UNAVAILABLE", "Unable to verify ABA PayWay payment");
        }
    }

    public boolean validCallback(Map<String, Object> body, String signature) {
        if (signature == null || signature.isBlank() || config.apiKey().isBlank()) return false;
        var sorted = new TreeMap<>(body);
        StringBuilder value = new StringBuilder();
        sorted.values().forEach(v -> value.append(v instanceof Map || v instanceof Iterable ? json.writeValueAsString(v) : v));
        return java.security.MessageDigest.isEqual(sign(value.toString()).getBytes(StandardCharsets.UTF_8),
                signature.getBytes(StandardCharsets.UTF_8));
    }

    private String encodeItems(OrderResponse order) {
        var items = order.items().stream().map(i -> Map.of("name", i.name(), "quantity", i.quantity(), "price", i.price())).toList();
        return Base64.getEncoder().encodeToString(json.writeValueAsBytes(items));
    }
    private String encodeUrl(String url) {
        if (url == null || url.isBlank()) return "";
        return Base64.getEncoder().encodeToString(url.getBytes(StandardCharsets.UTF_8));
    }
    private String sign(String value) {
        try {
            Mac mac = Mac.getInstance("HmacSHA512");
            mac.init(new SecretKeySpec(config.apiKey().getBytes(StandardCharsets.UTF_8), "HmacSHA512"));
            return Base64.getEncoder().encodeToString(mac.doFinal(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) { throw new IllegalStateException("Unable to sign PayWay request", e); }
    }
    private void requireConfigured() {
        if (config.apiKey() == null || config.apiKey().isBlank() || config.apiKey().startsWith("YOUR_"))
            throw ApiException.unavailable("PAYWAY_NOT_CONFIGURED", "ABA PayWay is not configured yet");
    }
}
