package com.forever.foreverapi.service.serviceImpl;

import com.forever.foreverapi.service.AuthService;
import com.forever.foreverapi.service.LoginAttemptLimiter;
import com.forever.foreverapi.service.NotificationService;
import com.forever.foreverapi.service.OtpService;

import com.forever.foreverapi.service.JwtService;
import com.forever.foreverapi.config.AppProperties;
import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.model.dto.AuthDtos.AuthResponse;
import com.forever.foreverapi.model.dto.AuthDtos.RegisterRequest;
import com.forever.foreverapi.model.dto.AuthDtos.RegisterResponse;
import com.forever.foreverapi.model.entity.OtpPurpose;
import com.forever.foreverapi.model.entity.RefreshToken;
import com.forever.foreverapi.repository.RefreshTokenRepository;
import com.forever.foreverapi.model.dto.UserDtos.UserResponse;
import com.forever.foreverapi.model.entity.Role;
import com.forever.foreverapi.model.entity.User;
import com.forever.foreverapi.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;

@Service
public class AuthServiceImpl implements AuthService {

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final PasswordEncoder encoder;
    private final JwtService jwt;
    private final OtpService otp;
    private final LoginAttemptLimiter loginLimiter;
    private final AppProperties props;
    private final NotificationService notifications;
    private final SecureRandom random = new SecureRandom();

    public AuthServiceImpl(UserRepository users, RefreshTokenRepository refreshTokens, PasswordEncoder encoder,
                       JwtService jwt, OtpService otp, LoginAttemptLimiter loginLimiter, AppProperties props,
                       NotificationService notifications) {
        this.notifications = notifications;
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.encoder = encoder;
        this.jwt = jwt;
        this.otp = otp;
        this.loginLimiter = loginLimiter;
        this.props = props;
    }

    @Transactional
    public RegisterResponse register(RegisterRequest req) {
        String email = normalize(req.email());
        User user = users.findByEmailIgnoreCase(email).orElse(null);
        if (user != null && user.isEmailVerified()) {
            throw ApiException.conflict("EMAIL_TAKEN", "An account with this email already exists");
        }
        if (user == null) {
            user = new User();
            user.setEmail(email);
        }
        // An unverified registration can be retried: refresh the name/password and send a new code.
        user.setName(req.name().trim());
        user.setPasswordHash(encoder.encode(req.password()));
        users.save(user);
        otp.issueAndSend(email, OtpPurpose.VERIFY_EMAIL);
        return new RegisterResponse("Verification code sent to your email", email, props.otp().ttl().toSeconds());
    }

    @Transactional
    public AuthResponse verifyEmail(String rawEmail, String code) {
        String email = normalize(rawEmail);
        User user = users.findByEmailIgnoreCase(email)
                .orElseThrow(() -> ApiException.badRequest("INVALID_OTP", "Invalid or expired code"));
        otp.verifyAndConsume(email, OtpPurpose.VERIFY_EMAIL, code);
        if (!user.isEmailVerified()) {
            notifications.notifyAdmins(NotificationService.NEW_CUSTOMER, "New customer: " + user.getName(), user.getEmail(),
                    "/admin/customers");
        }
        user.setEmailVerified(true);
        return issueTokens(users.save(user));
    }

    @Transactional
    public void resendOtp(String rawEmail, OtpPurpose purpose) {
        String email = normalize(rawEmail);
        // Same response whether or not the account exists, to avoid leaking registered emails.
        users.findByEmailIgnoreCase(email).ifPresent(user -> {
            if (purpose == OtpPurpose.VERIFY_EMAIL && user.isEmailVerified()) {
                return;
            }
            otp.issueAndSend(email, purpose);
        });
    }

    @Transactional(noRollbackFor = ApiException.class)
    public AuthResponse login(String rawEmail, String password) {
        String email = normalize(rawEmail);
        loginLimiter.assertNotLocked(email);
        User user = users.findByEmailIgnoreCase(email)
                .filter(u -> encoder.matches(password, u.getPasswordHash()))
                .orElse(null);
        if (user == null) {
            loginLimiter.recordFailure(email);
            throw ApiException.unauthorized("INVALID_CREDENTIALS", "Invalid email or password");
        }
        loginLimiter.recordSuccess(email);
        if (!user.isEnabled()) {
            throw ApiException.forbidden("ACCOUNT_DISABLED", "This account has been disabled");
        }
        if (!user.isEmailVerified()) {
            try {
                otp.issueAndSend(email, OtpPurpose.VERIFY_EMAIL);
            } catch (ApiException e) {
                if (e.getStatus() != HttpStatus.TOO_MANY_REQUESTS) {
                    throw e; // cooldown: a recent code is still valid, just report the unverified state
                }
            }
            throw ApiException.forbidden("EMAIL_NOT_VERIFIED",
                    "Email not verified. Check your inbox for the verification code, or request a new one");
        }
        return issueTokens(user);
    }

    @Transactional
    public AuthResponse refresh(String rawToken) {
        RefreshToken stored = refreshTokens.findByHash(hash(rawToken))
                .orElseThrow(() -> ApiException.unauthorized("INVALID_REFRESH_TOKEN", "Invalid refresh token"));
        if (stored.isRevoked() || stored.getExpiresAt().isBefore(Instant.now())) {
            throw ApiException.unauthorized("INVALID_REFRESH_TOKEN", "Refresh token expired or revoked");
        }
        User user = stored.getUser();
        if (!user.isEnabled()) {
            throw ApiException.forbidden("ACCOUNT_DISABLED", "This account has been disabled");
        }
        stored.setRevoked(true); // rotation: each refresh token works once
        return issueTokens(user);
    }

    @Transactional
    public void logout(String rawToken) {
        refreshTokens.findByHash(hash(rawToken)).ifPresent(t -> t.setRevoked(true));
    }

    @Transactional
    public void forgotPassword(String rawEmail) {
        String email = normalize(rawEmail);
        users.findByEmailIgnoreCase(email).filter(User::isEnabled)
                .ifPresent(u -> otp.issueAndSend(email, OtpPurpose.RESET_PASSWORD));
    }

    @Transactional
    public void resetPassword(String rawEmail, String code, String newPassword) {
        String email = normalize(rawEmail);
        User user = users.findByEmailIgnoreCase(email)
                .orElseThrow(() -> ApiException.badRequest("INVALID_OTP", "Invalid or expired code"));
        otp.verifyAndConsume(email, OtpPurpose.RESET_PASSWORD, code);
        user.setPasswordHash(encoder.encode(newPassword));
        user.setEmailVerified(true); // proving mailbox ownership via OTP
        users.save(user);
        refreshTokens.revokeAllForUser(user.getId());
        loginLimiter.recordSuccess(email); // a reset is the way out of a lockout
    }

    @Transactional
    public void changePassword(Long userId, String current, String newPassword) {
        User user = users.findById(userId)
                .orElseThrow(() -> ApiException.unauthorized("UNAUTHORIZED", "Account no longer exists"));
        if (!encoder.matches(current, user.getPasswordHash())) {
            throw ApiException.badRequest("WRONG_PASSWORD", "Current password is incorrect");
        }
        user.setPasswordHash(encoder.encode(newPassword));
        users.save(user);
        refreshTokens.revokeAllForUser(userId);
    }

    public User createAdminIfMissing(String email, String password) {
        return users.findByEmailIgnoreCase(email).orElseGet(() -> {
            User admin = new User();
            admin.setName("Administrator");
            admin.setEmail(email);
            admin.setPasswordHash(encoder.encode(password));
            admin.setRole(Role.ADMIN);
            admin.setEmailVerified(true);
            return users.save(admin);
        });
    }

    private AuthResponse issueTokens(User user) {
        byte[] raw = new byte[48];
        random.nextBytes(raw);
        String refresh = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);

        RefreshToken token = new RefreshToken();
        token.setUser(user);
        token.setTokenHash(hash(refresh));
        token.setExpiresAt(Instant.now().plus(props.jwt().refreshTokenTtl()));
        refreshTokens.save(token);

        return new AuthResponse(jwt.generateAccessToken(user), refresh, "Bearer", jwt.accessTtlSeconds(),
                UserResponse.from(user));
    }

    private static String normalize(String email) {
        return email.trim().toLowerCase();
    }

    private static String hash(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
