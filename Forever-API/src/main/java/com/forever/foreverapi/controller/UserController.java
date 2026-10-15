package com.forever.foreverapi.controller;

import com.forever.foreverapi.common.security.AuthUser;
import com.forever.foreverapi.common.response.MessageResponse;
import com.forever.foreverapi.service.AuthService;
import com.forever.foreverapi.model.dto.UserDtos.ChangePasswordRequest;
import com.forever.foreverapi.model.dto.UserDtos.UpdateProfileRequest;
import com.forever.foreverapi.model.dto.UserDtos.UserResponse;
import com.forever.foreverapi.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users/me")
@Tag(name = "Profile")
public class UserController {

    private final UserService users;
    private final AuthService auth;

    public UserController(UserService users, AuthService auth) {
        this.users = users;
        this.auth = auth;
    }

    @Operation(summary = "Current user profile")
    @GetMapping
    public UserResponse me(@AuthenticationPrincipal AuthUser principal) {
        return users.get(principal.id());
    }

    @Operation(summary = "Update name / phone")
    @PutMapping
    public UserResponse update(@AuthenticationPrincipal AuthUser principal, @Valid @RequestBody UpdateProfileRequest req) {
        return users.update(principal.id(), req);
    }

    @Operation(summary = "Change password (signs out all other sessions)")
    @PostMapping("/change-password")
    public MessageResponse changePassword(@AuthenticationPrincipal AuthUser principal,
                                          @Valid @RequestBody ChangePasswordRequest req) {
        auth.changePassword(principal.id(), req.currentPassword(), req.newPassword());
        return new MessageResponse("Password changed");
    }
}
