package com.forever.foreverapi.service;

import com.forever.foreverapi.common.security.ShopperRef;
import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.model.dto.OrderDtos.AddressDto;
import com.forever.foreverapi.model.dto.OrderDtos.PlaceOrderRequest;
import com.forever.foreverapi.model.dto.PaymentDtos.KhqrCheckout;
import com.forever.foreverapi.model.entity.Order;
import com.forever.foreverapi.model.entity.OrderStatus;
import com.forever.foreverapi.model.entity.PaymentMethod;
import com.forever.foreverapi.model.entity.Product;
import com.forever.foreverapi.repository.OrderRepository;
import com.forever.foreverapi.repository.ProductRepository;
import com.sun.net.httpserver.HttpServer;
import kh.gov.nbc.bakong_khqr.BakongKHQR;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * FIX-008: the KHQR lifecycle against a local fake of Bakong's check_transaction_by_md5 endpoint â no real
 * Bakong call and no real money. The QR itself is produced by the real Bakong SDK and decoded back here.
 * Not @Transactional: KhqrServiceImpl spans several transactions, as in production.
 */
@SpringBootTest
class KhqrPaymentFlowTest {

    private static final String ACCOUNT = "forever_test@aclb";
    private static final String TOKEN = "test-token";
    /** What the fake Bakong answers next: [status code, body]. */
    private static final AtomicReference<Object[]> REPLY = new AtomicReference<>();
    private static final AtomicReference<String> LAST_REQUEST = new AtomicReference<>();
    private static final AtomicReference<String> LAST_AUTH = new AtomicReference<>();
    private static final HttpServer BAKONG = startFakeBakong();

    private static HttpServer startFakeBakong() {
        try {
            HttpServer s = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
            s.createContext("/v1/check_transaction_by_md5", ex -> {
                LAST_REQUEST.set(new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
                LAST_AUTH.set(ex.getRequestHeaders().getFirst("Authorization"));
                Object[] reply = REPLY.get();
                byte[] body = ((String) reply[1]).getBytes(StandardCharsets.UTF_8);
                ex.getResponseHeaders().add("Content-Type", "application/json");
                ex.sendResponseHeaders((int) reply[0], body.length);
                ex.getResponseBody().write(body);
                ex.close();
            });
            s.start();
            return s;
        } catch (IOException e) {
            throw new IllegalStateException(e);
        }
    }

    @DynamicPropertySource
    static void khqr(DynamicPropertyRegistry r) {
        r.add("app.khqr.account-id", () -> ACCOUNT);
        r.add("app.khqr.api-token", () -> TOKEN);
        r.add("app.khqr.api-url", () -> "http://127.0.0.1:" + BAKONG.getAddress().getPort());
    }

    @AfterAll
    static void stopBakong() {
        BAKONG.stop(0);
    }

    @Autowired
    KhqrService khqr;
    @Autowired
    CartService cart;
    @Autowired
    com.forever.foreverapi.repository.UserRepository userRepo;
    @Autowired
    GuestSessionService guestSessions;
    @Autowired
    CommerceService commerce;
    @Autowired
    ProductRepository products;
    @Autowired
    OrderRepository orders;
    @Autowired
    JdbcClient db;

    private final List<ShopperRef> shoppers = new ArrayList<>();
    private Long productId;
    private String size;
    private Integer originalStock;

    @AfterEach
    void cleanUp() {
        for (ShopperRef s : shoppers) {
            String col = s.isGuest() ? "guest_session_id" : "user_id";
            Long id = s.isGuest() ? s.guestSessionId() : s.userId();
            db.sql("delete from orders where " + col + " = :id").param("id", id).update();
            db.sql(s.isGuest() ? "delete from guest_sessions where id = :id" : "delete from users where id = :id")
                    .param("id", id).update();
        }
        if (originalStock != null) commerce.setStock(productId, size, originalStock);
    }

    private ShopperRef customerWithCart() {
        return withCart(fixtures().customer());
    }

    private com.forever.foreverapi.TestShoppers fixtures() {
        return new com.forever.foreverapi.TestShoppers(userRepo, guestSessions);
    }

    private ShopperRef withCart(ShopperRef shopper) {
        var row = db.sql("select p.id, i.size from products p join product_inventory i on i.product_id = p.id"
                + " where p.active order by p.id, i.size limit 1").query().listOfRows().getFirst();
        productId = ((Number) row.get("id")).longValue();
        size = (String) row.get("size");
        originalStock = db.sql("select stock from product_inventory where product_id=:id and size=:s")
                .param("id", productId).param("s", size).query(Integer.class).single();
        commerce.setStock(productId, size, 10);
        shoppers.add(shopper);
        cart.add(shopper, productId, size, 2);
        return shopper;
    }

    private static PlaceOrderRequest khqrRequest(String key) {
        return new PlaceOrderRequest(new AddressDto("Jane", "Doe", "jane@example.com", "1 Main St", "Phnom Penh",
                "Phnom Penh", "12000", "Cambodia", "012345678"), PaymentMethod.KHQR, null, null, null, key);
    }

    private static Object[] found(String amount) {
        return new Object[]{200, "{\"responseCode\":0,\"responseMessage\":\"Getting transaction successfully.\","
                + "\"data\":{\"hash\":\"abc\",\"amount\":" + amount + ",\"currency\":\"USD\"}}"};
    }

    private static final Object[] NOT_FOUND = {200, "{\"responseCode\":1,\"responseMessage\":\"Transaction could not be found.\",\"data\":null}"};

    @Test
    void qrCarriesTheRealOrderAndPaymentIsOnlyConfirmedByBakong() {
        ShopperRef user = customerWithCart();
        String key = UUID.randomUUID().toString();

        KhqrCheckout checkout = khqr.checkout(user, khqrRequest(key));
        Order order = orders.findById(checkout.orderId()).orElseThrow();

        // Genuine payload: valid per the SDK, addressed to the merchant account, for the server-computed total.
        assertTrue(BakongKHQR.verify(checkout.qrString()).getData().isValid());
        var decoded = BakongKHQR.decode(checkout.qrString()).getData();
        assertEquals(ACCOUNT, decoded.getBakongAccountID());
        assertEquals("840", decoded.getTransactionCurrency()); // USD
        assertEquals(0, new java.math.BigDecimal(decoded.getTransactionAmount()).compareTo(order.getTotal()));
        assertEquals("ORDER" + order.getId(), decoded.getBillNumber());
        assertThat(checkout.qrImage()).startsWith("data:image/png;base64,");

        // Creating the order + QR is NOT a payment.
        assertEquals(OrderStatus.PAYMENT_PENDING, order.getStatus());
        assertFalse(order.isPaid());

        // A retried checkout gets the same QR back (same MD5), so nothing paid against it can be orphaned.
        KhqrCheckout replay = khqr.checkout(user, khqrRequest(key));
        assertEquals(checkout.orderId(), replay.orderId());
        assertEquals(checkout.qrString(), replay.qrString());

        REPLY.set(NOT_FOUND);
        var pending = khqr.verify(user.userId(), order.getId());
        assertFalse(pending.paid());
        assertEquals("PENDING", pending.status());
        assertThat(LAST_REQUEST.get()).contains(orders.findById(order.getId()).orElseThrow().getKhqrMd5());
        assertEquals("Bearer " + TOKEN, LAST_AUTH.get());

        REPLY.set(found(order.getTotal().subtract(java.math.BigDecimal.ONE).toPlainString()));
        assertFalse(khqr.verify(user.userId(), order.getId()).paid(), "an underpayment must not count");

        REPLY.set(found(order.getTotal().toPlainString()));
        var paid = khqr.verify(user.userId(), order.getId());
        assertTrue(paid.paid());
        assertEquals("PAID", paid.status());
        Order after = orders.findById(order.getId()).orElseThrow();
        assertTrue(after.isPaid());
        assertEquals(OrderStatus.ORDER_PLACED, after.getStatus());

        // Confirming twice is a no-op, and a paid order can't be re-checked-out.
        REPLY.set(NOT_FOUND);
        assertTrue(khqr.verify(user.userId(), order.getId()).paid());
        ApiException again = assertThrows(ApiException.class, () -> khqr.checkout(user, khqrRequest(key)));
        assertEquals("ORDER_ALREADY_PAID", again.getCode());
    }

    @Test
    void bakongOutageIsReportedAndNeverMarksTheOrderPaid() {
        ShopperRef user = customerWithCart();
        KhqrCheckout checkout = khqr.checkout(user, khqrRequest(UUID.randomUUID().toString()));

        REPLY.set(new Object[]{500, "{}"});
        ApiException e = assertThrows(ApiException.class, () -> khqr.verify(user.userId(), checkout.orderId()));
        assertEquals("KHQR_UNAVAILABLE", e.getCode());
        assertFalse(orders.findById(checkout.orderId()).orElseThrow().isPaid());
    }

    @Test
    void cancellingAnUnpaidKhqrOrderReleasesItsStock() {
        ShopperRef user = customerWithCart();
        KhqrCheckout checkout = khqr.checkout(user, khqrRequest(UUID.randomUUID().toString()));
        assertEquals(8, stockLeft());

        REPLY.set(NOT_FOUND);
        var status = khqr.cancel(user.userId(), checkout.orderId());
        assertEquals("CANCELLED", status.status());
        assertFalse(status.paid());
        assertEquals(10, stockLeft());
    }

    @Test
    void anotherCustomerCannotVerifyOrCancelSomeoneElsesPayment() {
        ShopperRef owner = customerWithCart();
        KhqrCheckout checkout = khqr.checkout(owner, khqrRequest(UUID.randomUUID().toString()));
        ShopperRef other = fixtures().customer();
        shoppers.add(other);

        assertThrows(ApiException.class, () -> khqr.verify(other.userId(), checkout.orderId()));
        assertThrows(ApiException.class, () -> khqr.cancel(other.userId(), checkout.orderId()));
    }

    private int stockLeft() {
        return db.sql("select stock from product_inventory where product_id=:id and size=:s")
                .param("id", productId).param("s", size).query(Integer.class).single();
    }

    @Test
    void aGuestPaysWithTheOrderAccessTokenOnly() {
        var guest = fixtures().guest();
        withCart(guest.ref());

        KhqrCheckout checkout = khqr.checkout(guest.ref(), khqrRequest(UUID.randomUUID().toString()));
        assertThat(checkout.guestAccessToken()).isNotBlank();
        Order order = orders.findById(checkout.orderId()).orElseThrow();
        assertThat(order.getUser()).isNull(); // a guest order belongs to no account

        REPLY.set(NOT_FOUND);
        assertEquals("PENDING", khqr.verifyAsGuest(checkout.orderId(), checkout.guestAccessToken()).status());
        // anyone without the token - including a wrong or missing one - gets "not found"
        ApiException wrong = assertThrows(ApiException.class, () -> khqr.verifyAsGuest(checkout.orderId(), "nope"));
        assertEquals(404, wrong.getStatus().value());
        assertThrows(ApiException.class, () -> khqr.verifyAsGuest(checkout.orderId(), null));

        REPLY.set(found(order.getTotal().toPlainString()));
        assertTrue(khqr.verifyAsGuest(checkout.orderId(), checkout.guestAccessToken()).paid());
    }

    @Test
    void aGuestGivingUpGetsTheLinesBackInItsOwnCartOnly() {
        var guest = fixtures().guest();
        withCart(guest.ref());
        KhqrCheckout checkout = khqr.checkout(guest.ref(), khqrRequest(UUID.randomUUID().toString()));
        assertEquals(0, cart.get(guest.ref()).items().size());

        REPLY.set(NOT_FOUND);
        assertEquals("CANCELLED", khqr.cancelAsGuest(checkout.orderId(), checkout.guestAccessToken()).status());
        assertEquals(2, cart.get(guest.ref()).items().getFirst().quantity());
        assertEquals(10, stockLeft());
    }
}
