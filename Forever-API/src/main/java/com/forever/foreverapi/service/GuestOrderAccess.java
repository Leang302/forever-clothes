package com.forever.foreverapi.service;

import com.forever.foreverapi.config.AppProperties;
import com.forever.foreverapi.model.entity.Order;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;

/**
 * Per-order secret that lets the guest who placed an order (and nobody else) see its confirmation and finish
 * paying for it. token = HMAC(server key, orderId:nonce): only the random nonce is stored, so a database read
 * alone doesn't reveal tokens, and a replayed checkout returns the same token. Expires; the order itself doesn't.
 */
@Component
public class GuestOrderAccess {

    private final byte[] key;
    private final Duration ttl;
    private final SecureRandom random = new SecureRandom();

    public GuestOrderAccess(AppProperties props, @Value("${app.guest.order-access-ttl:2d}") Duration ttl) {
        try {
            this.key = MessageDigest.getInstance("SHA-256")
                    .digest(("guest-order-access:" + props.jwt().secret()).getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
        this.ttl = ttl;
    }

    /** Arms [order] for guest access (new nonce + expiry). */
    public void grant(Order order) {
        byte[] nonce = new byte[16];
        random.nextBytes(nonce);
        order.setGuestAccessNonce(HexFormat.of().formatHex(nonce));
        order.setGuestAccessExpiresAt(Instant.now().plus(ttl));
    }

    /** The token for [order], or null if it isn't a guest order with access. */
    public String tokenFor(Order order) {
        if (order.getGuestAccessNonce() == null) return null;
        return Base64.getUrlEncoder().withoutPadding().encodeToString(mac(order.getId() + ":" + order.getGuestAccessNonce()));
    }

    public boolean allows(Order order, String token) {
        if (token == null || order.getGuestAccessNonce() == null || order.getGuestAccessExpiresAt() == null
                || !order.getGuestAccessExpiresAt().isAfter(Instant.now())) {
            return false;
        }
        String expected = tokenFor(order);
        return MessageDigest.isEqual(expected.getBytes(StandardCharsets.UTF_8), token.trim().getBytes(StandardCharsets.UTF_8));
    }

    private byte[] mac(String data) {
        try {
            Mac m = Mac.getInstance("HmacSHA256");
            m.init(new SecretKeySpec(key, "HmacSHA256"));
            return m.doFinal(data.getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
