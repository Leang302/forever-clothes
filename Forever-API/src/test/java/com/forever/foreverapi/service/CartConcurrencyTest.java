package com.forever.foreverapi.service;

import com.forever.foreverapi.TestShoppers;
import com.forever.foreverapi.common.security.ShopperRef;
import com.forever.foreverapi.repository.UserRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.context.request.RequestContextHolder;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Simultaneous "add to cart" for a line that isn't in the cart yet (double click / two tabs) used to make one
 * request fail with a unique-index violation (500) and lose its quantity. Real commits: not @Transactional.
 */
@SpringBootTest
class CartConcurrencyTest {

    private static final int THREADS = 6;

    @Autowired
    CartService cart;
    @Autowired
    CommerceService commerce;
    @Autowired
    UserRepository users;
    @Autowired
    GuestSessionService guestSessions;
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
        originalStock = db.sql("select stock from product_inventory where product_id = :id and size = :s")
                .param("id", productId).param("s", size).query(Integer.class).single();
        commerce.setStock(productId, size, 50);
    }

    @AfterEach
    void tearDown() {
        for (ShopperRef s : shoppers) {
            db.sql(s.isGuest() ? "delete from guest_sessions where id = :id" : "delete from users where id = :id")
                    .param("id", s.isGuest() ? s.guestSessionId() : s.userId()).update();
        }
        commerce.setStock(productId, size, originalStock);
    }

    private List<Throwable> raceAdds(ShopperRef shopper) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(THREADS);
        CountDownLatch start = new CountDownLatch(1);
        var request = RequestContextHolder.getRequestAttributes(); // cart lines build image URLs from it
        List<Future<?>> futures = new ArrayList<>();
        for (int i = 0; i < THREADS; i++) {
            futures.add(pool.submit(() -> {
                RequestContextHolder.setRequestAttributes(request);
                start.await();
                return cart.add(shopper, productId, size, 1);
            }));
        }
        start.countDown();
        List<Throwable> failures = new ArrayList<>();
        for (Future<?> f : futures) {
            try {
                f.get();
            } catch (java.util.concurrent.ExecutionException e) {
                failures.add(e.getCause());
            }
        }
        pool.shutdown();
        return failures;
    }

    private void assertAllAddsLanded(ShopperRef shopper) throws Exception {
        List<Throwable> failures = raceAdds(shopper);
        assertEquals(List.of(), failures);
        var lines = cart.get(shopper).items();
        assertEquals(1, lines.size());
        assertEquals(THREADS, lines.getFirst().quantity());
    }

    @Test
    void simultaneousAddsOfANewLineAllLandForACustomer() throws Exception {
        ShopperRef s = new TestShoppers(users, guestSessions).customer();
        shoppers.add(s);
        assertAllAddsLanded(s);
    }

    @Test
    void simultaneousAddsOfANewLineAllLandForAGuest() throws Exception {
        ShopperRef s = new TestShoppers(users, guestSessions).guest().ref();
        shoppers.add(s);
        assertAllAddsLanded(s);
    }
}
