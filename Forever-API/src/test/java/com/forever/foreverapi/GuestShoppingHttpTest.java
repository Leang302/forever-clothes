package com.forever.foreverapi;

import com.forever.foreverapi.model.entity.Role;
import com.forever.foreverapi.model.entity.User;
import com.forever.foreverapi.repository.UserRepository;
import com.forever.foreverapi.service.JwtService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Anonymous guest shopping end to end over real HTTP (security filters included): cart persistence, checkout,
 * privacy of guest orders, strict separation from registered accounts (no cart merge, no order migration).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class GuestShoppingHttpTest {

    @Value("${local.server.port}")
    int port;
    @Autowired
    JsonMapper json;
    @Autowired
    JdbcClient db;
    @Autowired
    UserRepository users;
    @Autowired
    PasswordEncoder encoder;
    @Autowired
    JwtService jwt;

    private final HttpClient http = HttpClient.newHttpClient();
    private final Instant started = Instant.now();
    private Long productId;
    private String size;
    private Long productId2;
    private String size2;

    @BeforeEach
    void pickProducts() {
        var rows = db.sql("select distinct on (p.id) p.id, i.size from products p join product_inventory i"
                + " on i.product_id = p.id where p.active and i.stock >= 5 order by p.id, i.size limit 2").query().listOfRows();
        productId = ((Number) rows.get(0).get("id")).longValue();
        size = (String) rows.get(0).get("size");
        productId2 = ((Number) rows.get(1).get("id")).longValue();
        size2 = (String) rows.get(1).get("size");
    }

    @AfterEach
    void cleanUp() {
        var since = Timestamp.from(started);
        db.sql("delete from orders where created_at >= :t and (user_id is null or user_id in"
                + " (select id from users where email like 'http-test+%'))").param("t", since).update();
        db.sql("delete from guest_sessions where created_at >= :t").param("t", since).update();
        db.sql("delete from users where email like 'http-test+%'").update();
    }

    // ---- helpers ----

    private HttpResponse<String> call(String method, String path, Map<String, String> headers, String body) throws Exception {
        var b = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path))
                .header("Content-Type", "application/json")
                .method(method, body == null ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofString(body));
        headers.forEach(b::header);
        return http.send(b.build(), HttpResponse.BodyHandlers.ofString());
    }

    private static Map<String, String> guest(String token) {
        return Map.of("X-Guest-Session", token);
    }

    private static Map<String, String> bearer(String token) {
        return Map.of("Authorization", "Bearer " + token);
    }

    private static Map<String, String> access(String token) {
        return token == null ? Map.of() : Map.of("X-Order-Access", token);
    }

    private JsonNode body(HttpResponse<String> r) {
        return json.readTree(r.body());
    }

    private String startGuest() throws Exception {
        var r = call("POST", "/api/guest-sessions", Map.of(), null);
        assertEquals(201, r.statusCode(), r.body());
        JsonNode n = body(r);
        assertThat(n.get("expiresAt").asString()).isNotBlank();
        assertThat(n.has("user")).isFalse(); // a guest session is not a login: no user, no JWT
        assertThat(n.has("accessToken")).isFalse();
        return n.get("token").asString();
    }

    private String registerAndLogin(String email) throws Exception {
        User u = new User();
        u.setName("Http Test");
        u.setEmail(email);
        u.setPasswordHash(encoder.encode("Password123"));
        u.setRole(Role.USER);
        u.setEmailVerified(true);
        users.save(u);
        var r = call("POST", "/api/auth/login", Map.of(), "{\"email\":\"" + email + "\",\"password\":\"Password123\"}");
        assertEquals(200, r.statusCode(), r.body());
        return body(r).get("accessToken").asString();
    }

    private HttpResponse<String> add(Map<String, String> who, Long product, String sz, int qty) throws Exception {
        return call("POST", "/api/cart/items", who, "{\"productId\":" + product + ",\"size\":\"" + sz + "\",\"quantity\":" + qty + "}");
    }

    private String orderBody(String email, String paymentMethod) {
        return """
                {"address":{"firstName":"Dara","lastName":"Sok","email":"%s","street":"12 Riverside",
                "city":"Phnom Penh","state":"PP","zipcode":"12000","country":"Cambodia","phone":"012345678"},
                "paymentMethod":"%s","idempotencyKey":"%s"}""".formatted(email, paymentMethod, UUID.randomUUID());
    }

    private int cartCount(Map<String, String> who) throws Exception {
        var r = call("GET", "/api/cart", who, null);
        assertEquals(200, r.statusCode(), r.body());
        return body(r).get("itemCount").asInt();
    }

    // ---- tests ----

    @Test
    void guestCartPersistsAcrossRequestsLikeARefreshOrAppRestart() throws Exception {
        String token = startGuest();
        assertEquals(200, add(guest(token), productId, size, 2).statusCode());

        // A "refresh"/"restart" is just a new request with the stored token: the cart is still there (in the DB).
        assertEquals(2, cartCount(guest(token)));
        assertEquals(2, cartCount(guest(token)));
        assertEquals(1L, db.sql("select count(*) from cart_items where guest_session_id = (select id from guest_sessions"
                + " where created_at >= :t order by id desc limit 1)").param("t", Timestamp.from(started)).query(Long.class).single());
    }

    @Test
    void guestCheckoutRequiresRealCustomerDetailsAndIsNotAnAccount() throws Exception {
        String token = startGuest();
        add(guest(token), productId, size, 1);

        var missing = call("POST", "/api/orders", guest(token), """
                {"address":{"firstName":"","lastName":"","email":"not-an-email","street":"","city":"","state":"",
                "zipcode":"","country":"","phone":""},"paymentMethod":"COD"}""");
        assertEquals(400, missing.statusCode(), missing.body());

        var placed = call("POST", "/api/orders", guest(token), orderBody("dara@example.com", "COD"));
        assertEquals(201, placed.statusCode(), placed.body());
        JsonNode order = body(placed);
        assertTrue(order.get("guest").asBoolean());
        assertTrue(order.get("userId").isNull());
        assertEquals("dara@example.com", order.get("address").get("email").asString()); // what they typed, nothing invented
        assertThat(order.get("guestAccessToken").asString()).isNotBlank();
        assertEquals(0, cartCount(guest(token))); // bought lines left the cart
    }

    @Test
    void aGuestIsNeverLoggedIn() throws Exception {
        String token = startGuest();
        for (String path : new String[]{"/api/users/me", "/api/orders", "/api/wishlist", "/api/users/me/addresses",
                "/api/admin/products", "/api/admin/orders"}) {
            int status = call("GET", path, guest(token), null).statusCode();
            assertTrue(status == 401 || status == 403, path + " -> " + status);
        }
        assertEquals(404, call("POST", "/api/auth/guest", Map.of(), null).statusCode()); // throwaway-account login is gone
    }

    @Test
    void guestOrderConfirmationIsOnlyForTheHolderOfItsAccessToken() throws Exception {
        String token = startGuest();
        add(guest(token), productId, size, 1);
        JsonNode order = body(call("POST", "/api/orders", guest(token), orderBody("dara@example.com", "COD")));
        long id = order.get("id").asLong();
        String accessToken = order.get("guestAccessToken").asString();

        var mine = call("GET", "/api/guest-orders/" + id, access(accessToken), null);
        assertEquals(200, mine.statusCode());
        assertEquals("Dara", body(mine).get("address").get("firstName").asString());
        assertTrue(body(mine).get("guestAccessToken").isNull()); // never re-disclosed

        assertEquals(404, call("GET", "/api/guest-orders/" + id, access(null), null).statusCode());
        assertEquals(404, call("GET", "/api/guest-orders/" + id, access("wrong-token"), null).statusCode());
        // the cart session itself does not open orders, and another guest's token doesn't either
        assertEquals(404, call("GET", "/api/guest-orders/" + id, guest(token), null).statusCode());
        String otherGuest = startGuest();
        add(guest(otherGuest), productId, size, 1);
        String otherAccess = body(call("POST", "/api/orders", guest(otherGuest), orderBody("x@example.com", "COD")))
                .get("guestAccessToken").asString();
        assertEquals(404, call("GET", "/api/guest-orders/" + id, access(otherAccess), null).statusCode());
        // a valid token for one order opens no other order (guessing neighbouring ids gets nothing)
        for (long guess = id - 3; guess <= id + 3; guess++) {
            if (guess == id) continue;
            assertEquals(404, call("GET", "/api/guest-orders/" + guess, access(accessToken), null).statusCode(),
                    "guess " + guess);
        }
        assertEquals(403, call("GET", "/api/orders/" + id, guest(token), null).statusCode());
    }

    @Test
    void loggingInShowsOnlyTheAccountsOwnCartAndOrdersNoMergeNoMigration() throws Exception {
        String email = "http-test+" + UUID.randomUUID() + "@example.com";
        // As a guest, using the same e-mail the account will have.
        String guestToken = startGuest();
        add(guest(guestToken), productId, size, 3);
        add(guest(guestToken), productId2, size2, 1);
        var guestOrder = body(call("POST", "/api/orders", guest(guestToken), orderBody(email, "COD")));
        add(guest(guestToken), productId, size, 1); // leave something in the guest cart

        String jwt = registerAndLogin(email);

        // The account's own cart: empty — the guest lines were NOT merged in.
        assertEquals(0, cartCount(bearer(jwt)));
        // The account's order history: nothing — the guest order (same e-mail) was NOT attached.
        var history = body(call("GET", "/api/orders", bearer(jwt), null));
        assertEquals(0, history.get("content").size());
        assertEquals(404, call("GET", "/api/orders/" + guestOrder.get("id").asLong(), bearer(jwt), null).statusCode());

        // The account shops separately...
        add(bearer(jwt), productId2, size2, 2);
        var accountOrder = body(call("POST", "/api/orders", bearer(jwt), orderBody(email, "COD")));
        assertTrue(accountOrder.get("guestAccessToken").isNull());
        assertThat(accountOrder.get("guest").asBoolean()).isFalse();
        assertEquals(1, body(call("GET", "/api/orders", bearer(jwt), null)).get("content").size());
        // ...and the guest cart is untouched by anything the account did.
        assertEquals(1, cartCount(guest(guestToken)));
        assertEquals(1L, db.sql("select count(*) from orders where id = :id and user_id is null")
                .param("id", guestOrder.get("id").asLong()).query(Long.class).single()); // still a guest order
    }

    @Test
    void sendingALoginAndAGuestSessionTogetherIsRefused() throws Exception {
        String token = startGuest();
        String jwt = registerAndLogin("http-test+" + UUID.randomUUID() + "@example.com");
        Map<String, String> both = new LinkedHashMap<>();
        both.putAll(guest(token));
        both.putAll(bearer(jwt));
        var r = call("GET", "/api/cart", both, null);
        assertEquals(400, r.statusCode());
        assertEquals("AMBIGUOUS_IDENTITY", body(r).get("code").asString());
    }

    @Test
    void anExpiredGuestSessionIsRejectedButPublicPagesStillWork() throws Exception {
        String token = startGuest();
        add(guest(token), productId, size, 1);
        db.sql("update guest_sessions set expires_at = now() - interval '1 second' where created_at >= :t")
                .param("t", Timestamp.from(started)).update();

        var cart = call("GET", "/api/cart", guest(token), null);
        assertEquals(401, cart.statusCode());
        assertEquals("GUEST_SESSION_EXPIRED", body(cart).get("code").asString());
        assertEquals(200, call("GET", "/api/products/latest?limit=1", guest(token), null).statusCode());
        assertEquals(401, call("GET", "/api/cart", guest("made-up-token"), null).statusCode());
    }

    @Test
    void endingAGuestSessionDiscardsItsCartSoTheNextPersonOnTheDeviceStartsClean() throws Exception {
        String token = startGuest();
        add(guest(token), productId, size, 1);
        assertEquals(204, call("DELETE", "/api/guest-sessions/current", guest(token), null).statusCode());
        assertEquals(401, call("GET", "/api/cart", guest(token), null).statusCode());
        assertEquals(0, cartCount(guest(startGuest())));
    }

    @Test
    void jwtsOfRetiredThrowawayGuestAccountsNoLongerWork() throws Exception {
        User legacy = new User();
        legacy.setName("Guest");
        legacy.setEmail("http-test+legacy-" + UUID.randomUUID() + "@guest.local");
        legacy.setPasswordHash("x");
        legacy.setRole(Role.GUEST);
        legacy.setEmailVerified(true);
        String token = jwt.generateAccessToken(users.save(legacy));

        assertEquals(403, call("GET", "/api/cart", bearer(token), null).statusCode());
        assertEquals(403, call("GET", "/api/users/me", bearer(token), null).statusCode());
    }
}
