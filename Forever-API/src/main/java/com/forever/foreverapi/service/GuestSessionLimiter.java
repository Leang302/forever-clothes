package com.forever.foreverapi.service;

import com.forever.foreverapi.exception.ApiException;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Caps how many guest sessions one client address can mint, so a script can't fill the users table.
 * A real shopper needs one per device/browser. In memory: with several API instances, use a shared store.
 */
@Component
public class GuestSessionLimiter {

    static final int MAX_PER_WINDOW = 20;
    static final Duration WINDOW = Duration.ofHours(1);

    private final Clock clock;
    private final ConcurrentHashMap<String, Deque<Instant>> starts = new ConcurrentHashMap<>();

    public GuestSessionLimiter() {
        this(Clock.systemUTC());
    }

    GuestSessionLimiter(Clock clock) {
        this.clock = clock;
    }

    /** Records one guest session for [clientKey]; throws 429 once the window's quota is used up. */
    public void acquire(String clientKey) {
        Instant now = clock.instant();
        Deque<Instant> times = starts.computeIfAbsent(clientKey, k -> new ArrayDeque<>());
        synchronized (times) {
            while (!times.isEmpty() && times.peekFirst().isBefore(now.minus(WINDOW))) times.pollFirst();
            if (times.size() >= MAX_PER_WINDOW) {
                throw ApiException.tooManyRequests("TOO_MANY_GUEST_SESSIONS",
                        "Too many guest sessions from this device. Please try again later or create an account");
            }
            times.addLast(now);
        }
    }

    @Scheduled(fixedDelay = 15 * 60 * 1000)
    void evictIdle() {
        Instant cutoff = clock.instant().minus(WINDOW);
        starts.entrySet().removeIf(e -> {
            synchronized (e.getValue()) {
                return e.getValue().isEmpty() || e.getValue().peekLast().isBefore(cutoff);
            }
        });
    }
}
