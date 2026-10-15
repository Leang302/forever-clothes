package com.forever.foreverapi.service;

import com.forever.foreverapi.config.AppProperties;
import com.forever.foreverapi.exception.ApiException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Throttles password guessing per e-mail address (unknown addresses are throttled the same way, so the
 * response never reveals whether an account exists). State is in memory: with several API instances,
 * move it to a shared store such as Redis.
 */
@Component
public class LoginAttemptLimiter {

    private record State(int failures, Instant windowStart, Instant lockedUntil) {
    }

    private final AppProperties.Login cfg;
    private final Clock clock;
    private final ConcurrentHashMap<String, State> states = new ConcurrentHashMap<>();

    @Autowired
    public LoginAttemptLimiter(AppProperties props) {
        this(props.login(), Clock.systemUTC());
    }

    LoginAttemptLimiter(AppProperties.Login cfg, Clock clock) {
        this.cfg = cfg;
        this.clock = clock;
    }

    /** Throws 429 while the address is locked. */
    public void assertNotLocked(String email) {
        State s = states.get(key(email));
        Instant now = clock.instant();
        if (s != null && s.lockedUntil() != null && now.isBefore(s.lockedUntil())) {
            long minutes = Math.max(1, Duration.between(now, s.lockedUntil()).toMinutes() + 1);
            throw ApiException.tooManyRequests("TOO_MANY_LOGIN_ATTEMPTS",
                    "Too many failed attempts. Try again in " + minutes + " minute" + (minutes == 1 ? "" : "s")
                            + " or reset your password.");
        }
    }

    public void recordFailure(String email) {
        Instant now = clock.instant();
        states.compute(key(email), (k, s) -> {
            if (s == null || now.isAfter(s.windowStart().plus(cfg.window()))
                    || (s.lockedUntil() != null && !now.isBefore(s.lockedUntil()))) {
                s = new State(0, now, null); // first failure, window expired, or lock elapsed: start over
            }
            int failures = s.failures() + 1;
            Instant lockedUntil = failures >= cfg.maxFailures() ? now.plus(cfg.lockout()) : null;
            return new State(failures, s.windowStart(), lockedUntil);
        });
    }

    public void recordSuccess(String email) {
        states.remove(key(email));
    }

    @Scheduled(fixedDelay = 600_000)
    void purge() {
        Instant now = clock.instant();
        states.entrySet().removeIf(e -> {
            State s = e.getValue();
            Instant end = s.lockedUntil() != null ? s.lockedUntil() : s.windowStart().plus(cfg.window());
            return now.isAfter(end);
        });
    }

    private static String key(String email) {
        return email.trim().toLowerCase();
    }
}
