package com.forever.foreverapi.model.dto;

import com.forever.foreverapi.model.entity.Role;
import com.forever.foreverapi.model.entity.User;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;

public final class UserDtos {

    private UserDtos() {
    }

    public record UserResponse(Long id, String name, String email, String phone, Role role, boolean emailVerified,
                               Instant createdAt) {
        public static UserResponse from(User u) {
            return new UserResponse(u.getId(), u.getName(), u.getEmail(), u.getPhone(), u.getRole(),
                    u.isEmailVerified(), u.getCreatedAt());
        }
    }

    public record UpdateProfileRequest(
            @NotBlank @Size(max = 120) String name,
            @Size(max = 40) String phone) {
    }

    public record ChangePasswordRequest(
            @NotBlank String currentPassword,
            @NotBlank @Size(min = 8, max = 72, message = "Password must be 8-72 characters") String newPassword) {
    }
}
