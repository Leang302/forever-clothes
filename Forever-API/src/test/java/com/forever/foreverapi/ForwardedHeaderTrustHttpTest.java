package com.forever.foreverapi;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * A client that is NOT a trusted proxy can't dodge the guest-session limit by rotating X-Forwarded-For.
 * `internal-proxies` is emptied here so even this loopback test client counts as an untrusted, public peer.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = "server.tomcat.remoteip.internal-proxies=")
class ForwardedHeaderTrustHttpTest {

    @Value("${local.server.port}")
    int port;
    @Autowired
    JdbcClient db;

    private final Instant started = Instant.now();
    private final HttpClient http = HttpClient.newHttpClient();

    @AfterEach
    void cleanUp() {
        db.sql("delete from guest_sessions where created_at >= :t")
                .param("t", java.sql.Timestamp.from(started)).update();
    }

    private int guest(String spoofedIp) throws Exception {
        var req = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/api/guest-sessions"))
                .header("X-Forwarded-For", spoofedIp)
                .POST(HttpRequest.BodyPublishers.noBody()).build();
        return http.send(req, HttpResponse.BodyHandlers.discarding()).statusCode();
    }

    @Test
    void rotatingXForwardedForDoesNotBypassTheGuestLimit() throws Exception {
        int ok = 0;
        int limited = 0;
        for (int i = 0; i < 25; i++) {
            int status = guest("203.0.113." + i); // a different "client IP" every time
            if (status == 201) ok++;
            if (status == 429) limited++;
        }
        assertEquals(20, ok, "only the per-client quota should succeed");
        assertTrue(limited >= 5, "the rest must be rate limited despite the spoofed header");
    }

    @Test
    void untrustedForwardedProtoDoesNotChangeMediaUrls() throws Exception {
        var req = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/api/products/latest?limit=1"))
                .header("X-Forwarded-Proto", "https").header("X-Forwarded-Host", "evil.example.com").GET().build();
        String body = http.send(req, HttpResponse.BodyHandlers.ofString()).body();
        assertTrue(body.contains("\"http://localhost:" + port + "/api/media/"), body.substring(0, Math.min(300, body.length())));
    }
}
