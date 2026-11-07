package com.forever.foreverapi.service;

import com.forever.foreverapi.model.entity.GuestSession;
import com.forever.foreverapi.repository.GuestSessionRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Expiry rules of anonymous cart sessions, with a controllable clock. Rolled back. */
@SpringBootTest
@Transactional
class GuestSessionServiceTest {

    private static class MutableClock extends Clock {
        Instant now = Instant.now();
        @Override public ZoneOffset getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(ZoneId zone) { return this; }
        @Override public Instant instant() { return now; }
    }

    @Autowired
    GuestSessionRepository repo;

    private final MutableClock clock = new MutableClock();

    private GuestSessionService service() {
        return new GuestSessionService(repo, Duration.ofDays(7), Duration.ofDays(30), clock);
    }

    @Test
    void tokenIsOpaqueAndOnlyItsHashIsStored() {
        var issued = service().create();
        assertThat(issued.token()).hasSizeGreaterThanOrEqualTo(40);
        GuestSession stored = repo.findByTokenHash(GuestSessionService.hash(issued.token())).orElseThrow();
        assertThat(stored.getTokenHash()).isNotEqualTo(issued.token()).hasSize(64);
    }

    @Test
    void idleSessionExpiresAndUseSlidesItForward() {
        var s = service();
        var issued = s.create();

        clock.now = clock.now.plus(Duration.ofDays(6));
        assertTrue(s.resolve(issued.token()).isPresent()); // still alive, and now extended to day 13
        clock.now = clock.now.plus(Duration.ofDays(6));
        assertTrue(s.resolve(issued.token()).isPresent());
        clock.now = clock.now.plus(Duration.ofDays(8)); // idle for more than 7 days
        assertTrue(s.resolve(issued.token()).isEmpty());
    }

    @Test
    void useNeverExtendsASessionPastItsMaximumLifetime() {
        var s = service();
        var issued = s.create();
        for (int day = 5; day < 30; day += 5) {
            clock.now = clock.now.plus(Duration.ofDays(5));
            assertTrue(s.resolve(issued.token()).isPresent(), "day " + day);
        }
        clock.now = clock.now.plus(Duration.ofDays(5)).plusSeconds(1); // day 30+: hard limit
        assertTrue(s.resolve(issued.token()).isEmpty());
    }

    @Test
    void revokedOrUnknownTokensResolveToNothing() {
        var s = service();
        var issued = s.create();
        s.revoke(issued.token());
        assertTrue(s.resolve(issued.token()).isEmpty());
        assertTrue(s.resolve("not-a-real-token").isEmpty());
        assertTrue(s.resolve(null).isEmpty());
        assertEquals(0, repo.findByTokenHash(GuestSessionService.hash(issued.token())).stream().count());
    }
}
