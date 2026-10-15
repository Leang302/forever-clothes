package com.forever.foreverapi.service;

import com.forever.foreverapi.common.security.AuthUser;
import com.forever.foreverapi.config.AppProperties;
import com.forever.foreverapi.model.entity.Role;
import com.forever.foreverapi.model.entity.User;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.util.Base64;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class JwtServiceTest {

    private static final String SECRET = Base64.getEncoder().encodeToString(new byte[48]);

    private static JwtService service(String secret, Duration ttl) {
        var props = new AppProperties(new AppProperties.Jwt(secret, ttl, Duration.ofDays(1)),
                null, null, null, null, null, null, null, null);
        return new JwtService(props);
    }

    private static User user() {
        User u = new User();
        u.setId(7L);
        u.setEmail("a@b.com");
        u.setRole(Role.ADMIN);
        return u;
    }

    @Test
    void roundTripsClaims() {
        JwtService jwt = service(SECRET, Duration.ofMinutes(5));
        AuthUser parsed = jwt.parse(jwt.generateAccessToken(user())).orElseThrow();
        assertEquals(7L, parsed.id());
        assertEquals("a@b.com", parsed.email());
        assertEquals("ADMIN", parsed.role());
    }

    @Test
    void rejectsExpiredTamperedAndForeignTokens() {
        JwtService jwt = service(SECRET, Duration.ofMinutes(5));
        String token = jwt.generateAccessToken(user());

        assertTrue(service(SECRET, Duration.ofSeconds(-5)).parse(
                service(SECRET, Duration.ofSeconds(-5)).generateAccessToken(user())).isEmpty(), "expired");
        String[] parts = token.split("\\.");
        String forgedPayload = Base64.getUrlEncoder().withoutPadding().encodeToString(
                ("{\"sub\":\"1\",\"email\":\"admin@forever.com\",\"role\":\"ADMIN\","
                        + "\"exp\":" + (System.currentTimeMillis() / 1000 + 600) + "}").getBytes());
        assertTrue(jwt.parse(parts[0] + "." + forgedPayload + "." + parts[2]).isEmpty(), "payload tampered");
        assertTrue(jwt.parse("not-a-jwt").isEmpty(), "garbage");

        String otherSecret = Base64.getEncoder().encodeToString(new byte[]{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
                14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32});
        assertTrue(service(otherSecret, Duration.ofMinutes(5)).parse(token).isEmpty(), "signed with another key");
    }

    @Test
    void refusesShortSecrets() {
        assertThrows(IllegalStateException.class, () -> service("short", Duration.ofMinutes(5)));
    }
}
