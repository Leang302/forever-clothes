package com.forever.foreverapi;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** With PUBLIC_API_URL set, image URLs use it even when the caller used an internal host (e.g. the SSR server). */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = "app.public-url=https://api.shop.example.test/")
class PublicMediaUrlHttpTest {

    @Value("${local.server.port}")
    int port;

    @Test
    void imageUrlsUseThePublicApiUrl() throws Exception {
        var req = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/api/products/latest?limit=3")).GET().build();
        String body = HttpClient.newHttpClient().send(req, HttpResponse.BodyHandlers.ofString()).body();
        assertTrue(body.contains("\"https://api.shop.example.test/api/media/"), body.substring(0, Math.min(300, body.length())));
        assertFalse(body.contains("localhost:" + port + "/api/media/"));
    }
}
