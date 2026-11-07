package com.forever.foreverapi.service;

import com.forever.foreverapi.common.security.ShopperRef;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Serializes everything that writes one shopper's cart or turns it into an order (Postgres transaction-scoped
 * advisory lock, released at commit/rollback). Concurrent duplicates — a double tap, two tabs, a retried request —
 * then run one after another and see each other's committed result instead of racing.
 */
@Component
public class ShopperLocks {

    /** First key of the two-int lock: registered customers vs guest cart sessions (ids from different tables). */
    private static final int CUSTOMER = 7311;
    private static final int GUEST_SESSION = 7312;

    private final JdbcClient db;

    public ShopperLocks(JdbcClient db) {
        this.db = db;
    }

    /** Must be called inside the caller's transaction (it holds the lock until that transaction ends). */
    @Transactional(propagation = Propagation.MANDATORY)
    public void lock(ShopperRef shopper) {
        long id = shopper.isGuest() ? shopper.guestSessionId() : shopper.userId();
        db.sql("select pg_advisory_xact_lock(:ns, :id)")
                .param("ns", shopper.isGuest() ? GUEST_SESSION : CUSTOMER)
                .param("id", (int) (id % Integer.MAX_VALUE))
                .query().listOfRows();
    }
}
