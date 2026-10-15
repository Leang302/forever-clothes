package com.forever.foreverapi.service;

import com.forever.foreverapi.common.security.AuthUser;
import com.forever.foreverapi.config.AppProperties;
import com.forever.foreverapi.model.entity.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.Optional;
import javax.crypto.SecretKey;

@Service
public class JwtService {

    private final SecretKey key;
    private final Duration accessTtl;

    public JwtService(AppProperties props) {
        this.key = buildKey(props.jwt().secret());
        this.accessTtl = props.jwt().accessTokenTtl();
    }

    public String generateAccessToken(User user) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(String.valueOf(user.getId()))
                .claim("email", user.getEmail())
                .claim("role", user.getRole().name())
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(accessTtl)))
                .signWith(key)
                .compact();
    }

    public long accessTtlSeconds() {
        return accessTtl.toSeconds();
    }

    public Optional<AuthUser> parse(String token) {
        try {
            Claims c = Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
            return Optional.of(new AuthUser(Long.valueOf(c.getSubject()), c.get("email", String.class),
                    c.get("role", String.class)));
        } catch (JwtException | IllegalArgumentException e) {
            return Optional.empty();
        }
    }

    private static SecretKey buildKey(String secret) {
        byte[] bytes;
        try {
            bytes = Decoders.BASE64.decode(secret);
        } catch (RuntimeException e) {
            bytes = secret.getBytes(StandardCharsets.UTF_8);
        }
        if (bytes.length < 32) {
            throw new IllegalStateException("app.jwt.secret must be at least 32 bytes");
        }
        return Keys.hmacShaKeyFor(bytes);
    }
}
