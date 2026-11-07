package com.forever.foreverapi.common.security;

/**
 * Who owns a cart / is placing an order: exactly one of a registered user or an anonymous guest cart session.
 * Resolved from the request's credentials (see ShopperArgumentResolver); never both.
 */
public record ShopperRef(Long userId, Long guestSessionId) {

    public ShopperRef {
        if ((userId == null) == (guestSessionId == null)) {
            throw new IllegalArgumentException("A shopper is either a user or a guest session");
        }
    }

    public static ShopperRef user(Long userId) {
        return new ShopperRef(userId, null);
    }

    public static ShopperRef guest(Long guestSessionId) {
        return new ShopperRef(null, guestSessionId);
    }

    public boolean isGuest() {
        return guestSessionId != null;
    }
}
