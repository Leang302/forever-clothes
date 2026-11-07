package com.forever.foreverapi.service;

import com.forever.foreverapi.common.security.ShopperRef;
import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.model.dto.OrderDtos.AddressDto;
import com.forever.foreverapi.model.dto.OrderDtos.OrderResponse;
import com.forever.foreverapi.model.dto.OrderDtos.PlaceOrderRequest;
import com.forever.foreverapi.model.entity.PaymentMethod;
import com.forever.foreverapi.model.entity.Product;
import com.forever.foreverapi.repository.ProductRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * FIX-007: duplicate submissions racing each other. Deliberately NOT @Transactional — every call commits for
 * real, as in production, so the advisory lock and unique index are exercised. Cleans up after itself.
 */
@SpringBootTest
class OrderConcurrencyTest {

    private static final int THREADS = 6;

    @Autowired
    OrderService orders;
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
    JdbcClient db;

    private final List<ShopperRef> shoppers = new ArrayList<>();
    private Long productId;
    private String size;
    private int originalStock;

    @BeforeEach
    void setUp() {
        var row = db.sql("select p.id, i.size from products p join product_inventory i on i.product_id = p.id"
                + " where p.active order by p.id, i.size limit 1").query().listOfRows().getFirst();
        productId = ((Number) row.get("id")).longValue();
        size = (String) row.get("size");
        originalStock = stock();
        commerce.setStock(productId, size, 50);
    }

    @AfterEach
    void tearDown() {
        for (ShopperRef s : shoppers) {
            String col = s.isGuest() ? "guest_session_id" : "user_id";
            Long id = s.isGuest() ? s.guestSessionId() : s.userId();
            db.sql("delete from orders where " + col + " = :id").param("id", id).update(); // items cascade
            db.sql(s.isGuest() ? "delete from guest_sessions where id = :id" : "delete from users where id = :id")
                    .param("id", id).update();
        }
        commerce.setStock(productId, size, originalStock);
    }

    private int stock() {
        return db.sql("select stock from product_inventory where product_id = :id and size = :size")
                .param("id", productId).param("size", size).query(Integer.class).single();
    }

    private ShopperRef customerWithCart(int quantity) {
        return withCart(new com.forever.foreverapi.TestShoppers(userRepo, guestSessions).customer(), quantity);
    }

    private ShopperRef guestWithCart(int quantity) {
        return withCart(new com.forever.foreverapi.TestShoppers(userRepo, guestSessions).guest().ref(), quantity);
    }

    private ShopperRef withCart(ShopperRef s, int quantity) {
        shoppers.add(s);
        cart.add(s, productId, size, quantity);
        return s;
    }

    private static PlaceOrderRequest request(String key, String street) {
        return new PlaceOrderRequest(new AddressDto("Jane", "Doe", "jane@example.com", street, "Phnom Penh",
                "Phnom Penh", "12000", "Cambodia", "012345678"), PaymentMethod.COD, null, null, null, key);
    }

    /** Runs [task] on THREADS threads released at the same instant; returns each outcome (value or exception). */
    private List<Object> race(Callable<OrderResponse> task) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(THREADS);
        CountDownLatch start = new CountDownLatch(1);
        // Responses build absolute image URLs from the current request; in production every call is on a
        // request thread, so give the workers the test's mock request too.
        var request = org.springframework.web.context.request.RequestContextHolder.getRequestAttributes();
        List<Future<OrderResponse>> futures = new ArrayList<>();
        for (int i = 0; i < THREADS; i++) {
            futures.add(pool.submit(() -> {
                org.springframework.web.context.request.RequestContextHolder.setRequestAttributes(request);
                start.await();
                return task.call();
            }));
        }
        start.countDown();
        List<Object> outcomes = new ArrayList<>();
        for (Future<OrderResponse> f : futures) {
            try {
                outcomes.add(f.get());
            } catch (java.util.concurrent.ExecutionException e) {
                outcomes.add(e.getCause());
            }
        }
        pool.shutdown();
        return outcomes;
    }

    private long orderCount(ShopperRef s) {
        return db.sql("select count(*) from orders where " + (s.isGuest() ? "guest_session_id" : "user_id") + " = :id")
                .param("id", s.isGuest() ? s.guestSessionId() : s.userId()).query(Long.class).single();
    }

    @Test
    void concurrentSubmissionsWithOneKeyCreateExactlyOneOrderAndReserveStockOnce() throws Exception {
        ShopperRef user = customerWithCart(2);
        String key = UUID.randomUUID().toString();

        List<Object> outcomes = race(() -> orders.place(user, request(key, "1 Main St")));

        assertThat(outcomes).allSatisfy(o -> assertThat(o).isInstanceOf(OrderResponse.class));
        assertThat(outcomes.stream().map(o -> ((OrderResponse) o).id()).distinct()).hasSize(1);
        assertEquals(1, orderCount(user));
        assertEquals(48, stock()); // 50 - 2, decremented exactly once
    }

    @Test
    void concurrentSubmissionsWithDifferentKeysStillBuyTheCartOnlyOnce() throws Exception {
        // e.g. the same cart checked out from two browser tabs at once
        ShopperRef user = customerWithCart(3);

        List<Object> outcomes = race(() -> orders.place(user, request(UUID.randomUUID().toString(), "1 Main St")));

        long created = outcomes.stream().filter(o -> o instanceof OrderResponse).count();
        assertEquals(1, created);
        assertThat(outcomes.stream().filter(o -> !(o instanceof OrderResponse)))
                .allSatisfy(o -> assertThat(((ApiException) o).getCode()).isEqualTo("CART_EMPTY"));
        assertEquals(1, orderCount(user));
        assertEquals(47, stock());
    }

    @Test
    void sameKeyWithDifferentDetailsIsRejected() {
        ShopperRef user = customerWithCart(1);
        String key = UUID.randomUUID().toString();
        orders.place(user, request(key, "1 Main St"));

        ApiException e = assertThrows(ApiException.class, () -> orders.place(user, request(key, "99 Other Rd")));
        assertEquals("IDEMPOTENCY_KEY_MISMATCH", e.getCode());
        assertEquals(1, orderCount(user));
    }

    @Test
    void aFailedAttemptRollsBackAndCanBeRetriedWithTheSameKey() {
        ShopperRef user = customerWithCart(5);
        String key = UUID.randomUUID().toString();
        commerce.setStock(productId, size, 4); // not enough: the attempt must roll back completely

        ApiException e = assertThrows(ApiException.class, () -> orders.place(user, request(key, "1 Main St")));
        assertEquals("OUT_OF_STOCK", e.getCode());
        assertEquals(0, orderCount(user));
        assertEquals(4, stock());
        assertEquals(1, cart.get(user).items().size()); // cart kept for the retry

        commerce.setStock(productId, size, 10);
        OrderResponse retried = orders.place(user, request(key, "1 Main St"));
        assertEquals(1, orderCount(user));
        assertEquals(5, stock());
        assertThat(retried.id()).isNotNull();
    }

    @Test
    void guestConcurrentSubmissionsWithOneKeyCreateExactlyOneGuestOrder() throws Exception {
        ShopperRef guest = guestWithCart(2);
        String key = UUID.randomUUID().toString();

        List<Object> outcomes = race(() -> orders.place(guest, request(key, "1 Main St")));

        assertThat(outcomes).allSatisfy(o -> assertThat(o).isInstanceOf(OrderResponse.class));
        assertThat(outcomes.stream().map(o -> ((OrderResponse) o).id()).distinct()).hasSize(1);
        // every replay hands back the same order-access token, so whichever response the client keeps works
        assertThat(outcomes.stream().map(o -> ((OrderResponse) o).guestAccessToken()).distinct()).hasSize(1);
        assertThat(((OrderResponse) outcomes.getFirst()).guestAccessToken()).isNotBlank();
        assertEquals(1, orderCount(guest));
        assertEquals(48, stock());
        assertEquals(0L, (long) db.sql("select count(*) from orders where guest_session_id = :g and user_id is not null")
                .param("g", guest.guestSessionId()).query(Long.class).single()); // a guest order is never an account order
    }

    @Test
    void aGuestCannotReplayAKeyUsedByARegisteredCustomerOrViceVersa() {
        ShopperRef customer = customerWithCart(1);
        String key = UUID.randomUUID().toString();
        orders.place(customer, request(key, "1 Main St"));
        ShopperRef guest = guestWithCart(1);

        ApiException e = assertThrows(ApiException.class, () -> orders.place(guest, request(key, "1 Main St")));
        assertEquals("IDEMPOTENCY_KEY_REUSED", e.getCode());
    }
}
