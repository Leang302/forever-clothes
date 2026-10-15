package com.forever.foreverapi.service;

import com.forever.foreverapi.config.AppProperties;
import com.forever.foreverapi.exception.ApiException;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class LoginAttemptLimiterTest {

    static class MutableClock extends Clock {
        Instant now = Instant.parse("2026-01-01T00:00:00Z");

        void advance(Duration d) {
            now = now.plus(d);
        }

        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }

    private final MutableClock clock = new MutableClock();
    private final LoginAttemptLimiter limiter = new LoginAttemptLimiter(
            new AppProperties.Login(3, Duration.ofMinutes(15), Duration.ofMinutes(15)), clock);

    private void fail(String email, int times) {
        for (int i = 0; i < times; i++) {
            limiter.assertNotLocked(email);
            limiter.recordFailure(email);
        }
    }

    @Test
    void locksAfterTheConfiguredNumberOfFailures() {
        fail("a@b.co", 3);
        ApiException e = assertThrows(ApiException.class, () -> limiter.assertNotLocked("a@b.co"));
        assertEquals(HttpStatus.TOO_MANY_REQUESTS, e.getStatus());
        assertEquals("TOO_MANY_LOGIN_ATTEMPTS", e.getCode());
    }

    @Test
    void staysOpenBelowTheLimitAndIsCaseInsensitive() {
        fail("A@B.co", 2);
        assertDoesNotThrow(() -> limiter.assertNotLocked("a@b.co"));
        limiter.recordFailure("a@b.CO");
        assertThrows(ApiException.class, () -> limiter.assertNotLocked("a@b.co"));
    }

    @Test
    void successClearsTheCounter() {
        fail("a@b.co", 2);
        limiter.recordSuccess("a@b.co");
        fail("a@b.co", 2);
        assertDoesNotThrow(() -> limiter.assertNotLocked("a@b.co"));
    }

    @Test
    void unlocksWhenTheLockoutElapses() {
        fail("a@b.co", 3);
        clock.advance(Duration.ofMinutes(16));
        assertDoesNotThrow(() -> limiter.assertNotLocked("a@b.co"));
        limiter.recordFailure("a@b.co"); // starts a fresh count rather than re-locking immediately
        assertDoesNotThrow(() -> limiter.assertNotLocked("a@b.co"));
    }

    @Test
    void oldFailuresOutsideTheWindowAreForgotten() {
        fail("a@b.co", 2);
        clock.advance(Duration.ofMinutes(20));
        fail("a@b.co", 2);
        assertDoesNotThrow(() -> limiter.assertNotLocked("a@b.co"));
    }

    @Test
    void otherAddressesAreUnaffected() {
        fail("a@b.co", 3);
        assertDoesNotThrow(() -> limiter.assertNotLocked("other@b.co"));
    }
}
