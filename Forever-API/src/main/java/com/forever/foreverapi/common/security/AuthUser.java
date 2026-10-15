package com.forever.foreverapi.common.security;

/** Authenticated principal rebuilt from the JWT claims on every request. */
public record AuthUser(Long id, String email, String role) {
}
