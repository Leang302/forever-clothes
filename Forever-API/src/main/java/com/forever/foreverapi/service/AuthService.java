package com.forever.foreverapi.service;

import com.forever.foreverapi.model.dto.AuthDtos.AuthResponse;
import com.forever.foreverapi.model.dto.AuthDtos.RegisterRequest;
import com.forever.foreverapi.model.dto.AuthDtos.RegisterResponse;
import com.forever.foreverapi.model.entity.OtpPurpose;
import com.forever.foreverapi.model.entity.User;

public interface AuthService {
    RegisterResponse register(RegisterRequest req);
    AuthResponse verifyEmail(String rawEmail, String code);
    void resendOtp(String rawEmail, OtpPurpose purpose);
    AuthResponse login(String rawEmail, String password);
    AuthResponse refresh(String rawToken);
    void logout(String rawToken);
    void forgotPassword(String rawEmail);
    void resetPassword(String rawEmail, String code, String newPassword);
    void changePassword(Long userId, String current, String newPassword);
    User createAdminIfMissing(String email, String password);
}
