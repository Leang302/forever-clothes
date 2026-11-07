package com.forever.foreverapi.common.security;

/** The authenticated principal for a request carrying a valid X-Guest-Session token (cart/checkout only). */
public record GuestPrincipal(Long sessionId) {
}
