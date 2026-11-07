package com.forever.foreverapi.job;

import com.forever.foreverapi.TestShoppers;
import com.forever.foreverapi.repository.UserRepository;
import com.forever.foreverapi.service.CartService;
import com.forever.foreverapi.service.GuestSessionService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.annotation.Transactional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Expiring guest sessions discards their carts but never their orders; retired GUEST accounts are removed
 * without touching real customers. Rolled back.
 */
@SpringBootTest
@Transactional
class GuestPurgeTest {

    @Autowired
    TokenCleanupJob job;
    @Autowired
    GuestSessionService guestSessions;
    @Autowired
    UserRepository users;
    @Autowired
    CartService cart;
    @Autowired
    JdbcClient db;

    private long count(String sql, Object id) {
        return db.sql(sql).param("id", id).query(Long.class).single();
    }

    @Test
    void expiredGuestSessionLosesItsCartButItsOrderIsKept() {
        var fixtures = new TestShoppers(users, guestSessions);
        var expired = fixtures.guest();
        var live = fixtures.guest();
        var row = db.sql("select p.id, i.size from products p join product_inventory i on i.product_id = p.id"
                + " where p.active and i.stock > 0 order by p.id limit 1").query().listOfRows().getFirst();
        Long productId = ((Number) row.get("id")).longValue();
        cart.add(expired.ref(), productId, (String) row.get("size"), 1);
        cart.add(live.ref(), productId, (String) row.get("size"), 1);
        // an order placed from the soon-expired session
        Long orderId = db.sql("select id from orders order by id limit 1").query(Long.class).single();
        db.sql("update orders set guest_session_id = :g, user_id = null where id = :o")
                .param("g", expired.ref().guestSessionId()).param("o", orderId).update();
        db.sql("update guest_sessions set expires_at = now() - interval '1 minute' where id = :id")
                .param("id", expired.ref().guestSessionId()).update();

        job.purge();

        assertEquals(0, count("select count(*) from guest_sessions where id = :id", expired.ref().guestSessionId()));
        assertEquals(0, count("select count(*) from cart_items where guest_session_id = :id", expired.ref().guestSessionId()));
        assertEquals(1, count("select count(*) from orders where id = :id", orderId)); // business record stays
        assertEquals(0, count("select count(*) from orders where id = :id and guest_session_id is not null", orderId));
        assertEquals(1, count("select count(*) from cart_items where guest_session_id = :id", live.ref().guestSessionId()));
    }

    @Test
    void retiredGuestAccountsAreRemovedAndRealCustomersKept() {
        Long legacyGuest = db.sql("insert into users(name, email, password_hash, role, email_verified)"
                + " values ('Guest', 'guest+legacy-test@guest.local', 'x', 'GUEST', true) returning id").query(Long.class).single();
        Long customer = new TestShoppers(users, guestSessions).customer().userId();

        job.purge();

        assertEquals(0, count("select count(*) from users where id = :id", legacyGuest));
        assertEquals(1, count("select count(*) from users where id = :id", customer));
        assertTrue(count("select count(*) from users where role = :id", "GUEST") == 0);
    }
}
