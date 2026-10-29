package com.forever.foreverapi.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.math.BigDecimal;
import java.time.Duration;

@ConfigurationProperties(prefix = "app")
public record AppProperties(Jwt jwt, Otp otp, Login login, Mail mail, Minio minio, Shop shop, Seed seed, Cors cors,
                            Khqr khqr) {

    public record Jwt(String secret, Duration accessTokenTtl, Duration refreshTokenTtl) {
    }

    public record Otp(int length, Duration ttl, int maxAttempts, Duration resendCooldown, boolean logCode) {
    }

    /** Brute-force protection: after [maxFailures] wrong passwords within [window] the account is locked for [lockout]. */
    public record Login(int maxFailures, Duration window, Duration lockout) {
    }

    public record Mail(String from) {
    }

    public record Minio(String endpoint, String accessKey, String secretKey, String bucket) {
    }

    public record Shop(String currency, BigDecimal deliveryFee) {
    }

    public record Seed(boolean enabled, String adminEmail, String adminPassword) {
    }

    public record Cors(String allowedOriginPatterns) {
    }

    /** Bakong KHQR: payments go to [accountId]; [apiToken] (Bakong Open API, renewed every 90 days) checks them. */
    public record Khqr(String accountId, String merchantName, String merchantCity, String apiUrl, String apiToken,
                       Duration qrTtl) {
    }
}
