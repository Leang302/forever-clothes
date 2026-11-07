package com.forever.foreverapi;

import com.forever.foreverapi.common.security.ShopperRef;
import com.forever.foreverapi.model.entity.Role;
import com.forever.foreverapi.model.entity.User;
import com.forever.foreverapi.repository.UserRepository;
import com.forever.foreverapi.service.GuestSessionService;

import java.util.UUID;

/** Test fixtures: a real registered customer row, or a real anonymous guest cart session. */
public final class TestShoppers {

    public record Guest(ShopperRef ref, String token) {
    }

    private final UserRepository users;
    private final GuestSessionService guestSessions;

    public TestShoppers(UserRepository users, GuestSessionService guestSessions) {
        this.users = users;
        this.guestSessions = guestSessions;
    }

    public ShopperRef customer() {
        User u = new User();
        u.setName("Test Customer");
        u.setEmail("test+" + UUID.randomUUID() + "@example.com");
        u.setPasswordHash("{noop}unused");
        u.setRole(Role.USER);
        u.setEmailVerified(true);
        return ShopperRef.user(users.save(u).getId());
    }

    public Guest guest() {
        var issued = guestSessions.create();
        return new Guest(ShopperRef.guest(guestSessions.resolve(issued.token()).orElseThrow()), issued.token());
    }
}
