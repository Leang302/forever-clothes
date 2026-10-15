package com.forever.foreverapi.controller;

import com.forever.foreverapi.common.response.MessageResponse;
import com.forever.foreverapi.model.dto.AuthDtos.AuthResponse;
import com.forever.foreverapi.model.dto.AuthDtos.ForgotPasswordRequest;
import com.forever.foreverapi.model.dto.AuthDtos.LoginRequest;
import com.forever.foreverapi.model.dto.AuthDtos.RefreshRequest;
import com.forever.foreverapi.model.dto.AuthDtos.RegisterRequest;
import com.forever.foreverapi.model.dto.AuthDtos.RegisterResponse;
import com.forever.foreverapi.model.dto.AuthDtos.ResendOtpRequest;
import com.forever.foreverapi.model.dto.AuthDtos.ResetPasswordRequest;
import com.forever.foreverapi.model.dto.AuthDtos.VerifyEmailRequest;
import com.forever.foreverapi.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/auth")
@Tag(name = "Auth", description = "Register, e-mail OTP verification, JWT login/refresh and password reset")
@SecurityRequirements
public class AuthController {

    private final AuthService auth;

    public AuthController(AuthService auth) {
        this.auth = auth;
    }

    @Operation(summary = "Create an account and e-mail a verification OTP")
    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    public RegisterResponse register(@Valid @RequestBody RegisterRequest req) {
        return auth.register(req);
    }

    @Operation(summary = "Verify e-mail with the OTP; returns tokens (logs the user in)")
    @PostMapping("/verify-email")
    public AuthResponse verifyEmail(@Valid @RequestBody VerifyEmailRequest req) {
        return auth.verifyEmail(req.email(), req.otp());
    }

    @Operation(summary = "Resend an OTP (VERIFY_EMAIL or RESET_PASSWORD); 60s cooldown")
    @PostMapping("/resend-otp")
    public MessageResponse resendOtp(@Valid @RequestBody ResendOtpRequest req) {
        auth.resendOtp(req.email(), req.purpose());
        return new MessageResponse("If the account exists, a new code has been sent");
    }

    @Operation(summary = "Log in with e-mail and password",
            description = "Returns 403 `EMAIL_NOT_VERIFIED` (and sends a fresh OTP) if the e-mail is not verified yet.")
    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest req) {
        return auth.login(req.email(), req.password());
    }

    @Operation(summary = "Exchange a refresh token for a new token pair (the old refresh token is revoked)")
    @PostMapping("/refresh")
    public AuthResponse refresh(@Valid @RequestBody RefreshRequest req) {
        return auth.refresh(req.refreshToken());
    }

    @Operation(summary = "Revoke a refresh token")
    @PostMapping("/logout")
    public MessageResponse logout(@Valid @RequestBody RefreshRequest req) {
        auth.logout(req.refreshToken());
        return new MessageResponse("Logged out");
    }

    @Operation(summary = "Start password reset: e-mails an OTP if the account exists")
    @PostMapping("/forgot-password")
    public MessageResponse forgotPassword(@Valid @RequestBody ForgotPasswordRequest req) {
        auth.forgotPassword(req.email());
        return new MessageResponse("If the account exists, a reset code has been sent");
    }

    @Operation(summary = "Finish password reset with e-mail + OTP + new password")
    @PostMapping("/reset-password")
    public MessageResponse resetPassword(@Valid @RequestBody ResetPasswordRequest req) {
        auth.resetPassword(req.email(), req.otp(), req.newPassword());
        return new MessageResponse("Password updated, please log in");
    }
}
