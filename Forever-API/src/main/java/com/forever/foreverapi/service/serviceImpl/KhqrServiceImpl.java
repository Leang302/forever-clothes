package com.forever.foreverapi.service.serviceImpl;

import com.forever.foreverapi.config.AppProperties;
import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.model.dto.OrderDtos.OrderResponse;
import com.forever.foreverapi.model.dto.OrderDtos.PlaceOrderRequest;
import com.forever.foreverapi.model.dto.PaymentDtos.KhqrCheckout;
import com.forever.foreverapi.model.dto.PaymentDtos.KhqrPaymentStatus;
import com.forever.foreverapi.model.entity.Order;
import com.forever.foreverapi.model.entity.OrderStatus;
import com.forever.foreverapi.model.entity.PaymentMethod;
import com.forever.foreverapi.repository.OrderRepository;
import com.forever.foreverapi.service.KhqrService;
import com.forever.foreverapi.service.OrderService;
import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.qrcode.QRCodeWriter;
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel;
import kh.gov.nbc.bakong_khqr.BakongKHQR;
import kh.gov.nbc.bakong_khqr.model.IndividualInfo;
import kh.gov.nbc.bakong_khqr.model.KHQRCurrency;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import tools.jackson.databind.json.JsonMapper;
import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;

@Service
public class KhqrServiceImpl implements KhqrService {
    private static final Logger log = LoggerFactory.getLogger(KhqrServiceImpl.class);
    private static final int QR_SIZE = 320;
    private final AppProperties.Khqr config;
    private final JsonMapper json;
    private final OrderService orders;
    private final OrderRepository orderRepository;
    private final OkHttpClient http = new OkHttpClient();
    public KhqrServiceImpl(AppProperties props, JsonMapper json, OrderService orders, OrderRepository orderRepository) {
        this.config = props.khqr(); this.json = json; this.orders = orders; this.orderRepository = orderRepository;
    }

    public KhqrCheckout checkout(Long userId, PlaceOrderRequest request) {
        requireConfigured();
        if (request.paymentMethod() != PaymentMethod.KHQR) {
            throw ApiException.badRequest("PAYMENT_MISMATCH", "Payment method must be KHQR");
        }
        OrderResponse order = orders.place(userId, request);
        try {
            Instant expiresAt = Instant.now().plus(config.qrTtl());
            var info = new IndividualInfo();
            info.setBakongAccountId(config.accountId());
            info.setMerchantName(config.merchantName());
            info.setMerchantCity(config.merchantCity());
            info.setCurrency(KHQRCurrency.USD);
            info.setAmount(order.total().doubleValue());
            info.setBillNumber("ORDER" + order.id());
            info.setExpirationTimestamp(expiresAt.toEpochMilli());
            var result = BakongKHQR.generateIndividual(info);
            if (result.getKHQRStatus().getCode() != 0 || result.getData() == null) {
                throw new IllegalStateException(result.getKHQRStatus().getMessage());
            }
            String qr = result.getData().getQr();
            orders.recordKhqrPayment(order.id(), result.getData().getMd5());
            return new KhqrCheckout(order.id(), qr, qrImage(qr), order.total(), "USD", config.merchantName(), expiresAt);
        } catch (Exception e) {
            log.warn("KHQR checkout failed for order {}: {}", order.id(), e.toString());
            orders.abortOnlinePayment(userId, order.id());
            throw ApiException.unavailable("KHQR_UNAVAILABLE", "Could not create the KHQR payment code");
        }
    }

    public KhqrPaymentStatus verify(Long userId, Long orderId) {
        requireConfigured();
        Order order = orderRepository.findByIdAndUserId(orderId, userId)
                .orElseThrow(() -> ApiException.notFound("Order not found"));
        if (order.getPaymentMethod() != PaymentMethod.KHQR) {
            throw ApiException.badRequest("PAYMENT_MISMATCH", "Order is not a KHQR order");
        }
        // Cancelled orders are checked too, so a payment that landed after giving up is still recorded.
        boolean paid = order.isPaid() || paidOnBakong(order);
        if (paid && !order.isPaid()) orders.confirmOnlinePayment(orderId);
        if (order.getStatus() == OrderStatus.CANCELLED) return new KhqrPaymentStatus(paid, "CANCELLED");
        return new KhqrPaymentStatus(paid, paid ? "PAID" : "PENDING");
    }

    public KhqrPaymentStatus cancel(Long userId, Long orderId) {
        KhqrPaymentStatus status;
        try {
            status = verify(userId, orderId);
        } catch (ApiException e) {
            if (!"KHQR_UNAVAILABLE".equals(e.getCode())) throw e;
            // Bakong is unreachable: let the customer give up anyway rather than keep the stock reserved.
            log.warn("Cancelling KHQR order {} without checking Bakong", orderId);
            status = new KhqrPaymentStatus(false, "PENDING");
        }
        if (status.paid() || "CANCELLED".equals(status.status())) return status;
        orders.abortOnlinePayment(userId, orderId);
        return new KhqrPaymentStatus(false, "CANCELLED");
    }

    /** Looks the QR up by its MD5 in the Bakong Open API; a transaction found for it means it was paid. */
    private boolean paidOnBakong(Order order) {
        if (order.getKhqrMd5() == null) return false;
        var body = RequestBody.create(json.writeValueAsString(Map.of("md5", order.getKhqrMd5())),
                MediaType.get("application/json"));
        var request = new Request.Builder()
                .url(config.apiUrl().replaceAll("/+$", "") + "/v1/check_transaction_by_md5")
                .header("Authorization", "Bearer " + config.apiToken())
                .post(body).build();
        try (var response = http.newCall(request).execute()) {
            if (response.code() == 401) log.warn("Bakong rejected the KHQR API token; it may have expired");
            if (!response.isSuccessful() || response.body() == null) {
                throw new IllegalStateException("Bakong returned HTTP " + response.code());
            }
            @SuppressWarnings("unchecked")
            Map<String, Object> result = json.readValue(response.body().string(), Map.class);
            if (!"0".equals(String.valueOf(result.get("responseCode")))
                    || !(result.get("data") instanceof Map<?, ?> data)) return false;
            BigDecimal amount = new BigDecimal(String.valueOf(data.get("amount")));
            if (amount.compareTo(order.getTotal()) != 0) {
                log.warn("KHQR payment for order {} was {} but the order total is {}", order.getId(), amount, order.getTotal());
                return false;
            }
            return true;
        } catch (Exception e) {
            log.warn("KHQR check failed for order {}: {}", order.getId(), e.toString());
            throw ApiException.unavailable("KHQR_UNAVAILABLE", "Unable to check the KHQR payment with Bakong");
        }
    }

    private static String qrImage(String content) throws Exception {
        var matrix = new QRCodeWriter().encode(content, BarcodeFormat.QR_CODE, QR_SIZE, QR_SIZE,
                Map.of(EncodeHintType.ERROR_CORRECTION, ErrorCorrectionLevel.M, EncodeHintType.MARGIN, 1));
        var image = new BufferedImage(matrix.getWidth(), matrix.getHeight(), BufferedImage.TYPE_BYTE_BINARY);
        for (int x = 0; x < matrix.getWidth(); x++) {
            for (int y = 0; y < matrix.getHeight(); y++) image.setRGB(x, y, matrix.get(x, y) ? 0x000000 : 0xFFFFFF);
        }
        var png = new ByteArrayOutputStream();
        ImageIO.write(image, "png", png);
        return "data:image/png;base64," + Base64.getEncoder().encodeToString(png.toByteArray());
    }

    private void requireConfigured() {
        if (config.accountId() == null || config.accountId().isBlank()
                || config.apiToken() == null || config.apiToken().isBlank())
            throw ApiException.unavailable("KHQR_NOT_CONFIGURED", "KHQR payment is not configured yet");
    }
}
