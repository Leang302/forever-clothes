package com.forever.foreverapi.service;

import com.forever.foreverapi.exception.ApiException;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class GuestSessionLimiterTest {

    private static class MutableClock extends Clock {
        Instant now = Instant.parse("2026-01-01T00:00:00Z");
        @Override public ZoneOffset getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(java.time.ZoneId zone) { return this; }
        @Override public Instant instant() { return now; }
    }

    @Test
    void capsGuestSessionsPerClientAndRecoversAfterTheWindow() {
        var clock = new MutableClock();
        var limiter = new GuestSessionLimiter(clock);
        for (int i = 0; i < GuestSessionLimiter.MAX_PER_WINDOW; i++) limiter.acquire("1.2.3.4");

        ApiException e = assertThrows(ApiException.class, () -> limiter.acquire("1.2.3.4"));
        assertEquals("TOO_MANY_GUEST_SESSIONS", e.getCode());
        assertDoesNotThrow(() -> limiter.acquire("5.6.7.8")); // other clients unaffected

        clock.now = clock.now.plus(GuestSessionLimiter.WINDOW).plusSeconds(1);
        assertDoesNotThrow(() -> limiter.acquire("1.2.3.4"));
    }
}
