package com.forever.foreverapi.service;

import com.forever.foreverapi.model.entity.GuestSession;
import com.forever.foreverapi.repository.GuestSessionRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Optional;

/**
 * Anonymous cart sessions. The client holds an opaque random token; only its SHA-256 is stored. A session slides
 * forward on use (idle TTL) but never past an absolute lifetime, so a shared device can't keep one forever.
 */
@Service
public class GuestSessionService {

    public record Issued(String token, Instant expiresAt) {
    }

    private final GuestSessionRepository sessions;
    private final Duration idleTtl;
    private final Duration maxTtl;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();

    @org.springframework.beans.factory.annotation.Autowired
    public GuestSessionService(GuestSessionRepository sessions,
                               @Value("${app.guest.session-idle-ttl:7d}") Duration idleTtl,
                               @Value("${app.guest.session-max-ttl:30d}") Duration maxTtl) {
        this(sessions, idleTtl, maxTtl, Clock.systemUTC());
    }

    GuestSessionService(GuestSessionRepository sessions, Duration idleTtl, Duration maxTtl, Clock clock) {
        this.sessions = sessions;
        this.idleTtl = idleTtl;
        this.maxTtl = maxTtl;
        this.clock = clock;
    }

    @Transactional
    public Issued create() {
        byte[] raw = new byte[32];
        random.nextBytes(raw);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        Instant now = clock.instant();
        GuestSession s = new GuestSession();
        s.setTokenHash(hash(token));
        s.setCreatedAt(now);
        s.setLastSeenAt(now);
        s.setExpiresAt(now.plus(idleTtl));
        sessions.save(s);
        return new Issued(token, s.getExpiresAt());
    }

    /** The live session for [token], extending its idle expiry; empty if unknown or expired. */
    @Transactional
    public Optional<Long> resolve(String token) {
        if (token == null || token.isBlank() || token.length() > 100) return Optional.empty();
        Instant now = clock.instant();
        return sessions.findByTokenHash(hash(token.trim()))
                .filter(s -> s.getExpiresAt().isAfter(now))
                .map(s -> {
                    if (Duration.between(s.getLastSeenAt(), now).compareTo(Duration.ofMinutes(1)) > 0) {
                        Instant slid = now.plus(idleTtl);
                        Instant cap = s.getCreatedAt().plus(maxTtl);
                        s.setExpiresAt(slid.isBefore(cap) ? slid : cap);
                        s.setLastSeenAt(now);
                    }
                    return s.getId();
                });
    }

    /** Ends the session now; its cart lines are deleted with it, orders placed with it are kept. */
    @Transactional
    public void revoke(String token) {
        if (token == null || token.isBlank()) return;
        sessions.findByTokenHash(hash(token.trim())).ifPresent(sessions::delete);
    }

    @Transactional
    public int purgeExpired() {
        return sessions.deleteExpired(clock.instant());
    }

    static String hash(String token) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
