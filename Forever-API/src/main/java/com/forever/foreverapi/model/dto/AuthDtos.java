package com.forever.foreverapi.model.dto;

import com.forever.foreverapi.model.entity.OtpPurpose;
import com.forever.foreverapi.model.dto.UserDtos.UserResponse;
import io.swagger.v3.oas.annotations.media.Schema;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public final class AuthDtos {

    private AuthDtos() {
    }

    public record RegisterRequest(
            @NotBlank @Size(max = 120) String name,
            @NotBlank @Email @Size(max = 190) String email,
            @NotBlank @Size(min = 8, max = 72, message = "Password must be 8-72 characters") String password) {
    }

    public record RegisterResponse(String message, String email, long otpExpiresInSeconds) {
    }

    public record VerifyEmailRequest(
            @NotBlank @Email String email,
            @NotBlank @Pattern(regexp = "\\d{4,8}", message = "OTP must be numeric") String otp) {
    }

    public record ResendOtpRequest(
            @NotBlank @Email String email,
            @NotNull OtpPurpose purpose) {
    }

    public record LoginRequest(
            @NotBlank @Email String email,
            @NotBlank String password) {
    }

    public record RefreshRequest(@NotBlank String refreshToken) {
    }

    public record ForgotPasswordRequest(@NotBlank @Email String email) {
    }

    public record ResetPasswordRequest(
            @NotBlank @Email String email,
            @NotBlank @Pattern(regexp = "\\d{4,8}", message = "OTP must be numeric") String otp,
            @NotBlank @Size(min = 8, max = 72, message = "Password must be 8-72 characters") String newPassword) {
    }

    public record AuthResponse(
            String accessToken,
            String refreshToken,
            @Schema(example = "Bearer") String tokenType,
            @Schema(description = "Access token lifetime in seconds") long expiresIn,
            UserResponse user) {
    }
}
