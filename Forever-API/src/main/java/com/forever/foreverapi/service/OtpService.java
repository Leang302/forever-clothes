package com.forever.foreverapi.service;

import com.forever.foreverapi.client.mail.EmailService;
import com.forever.foreverapi.config.AppProperties;
import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.model.entity.OtpCode;
import com.forever.foreverapi.model.entity.OtpPurpose;
import com.forever.foreverapi.repository.OtpCodeRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;

@Slf4j
@Service
public class OtpService {

    private final OtpCodeRepository repo;
    private final EmailService email;
    private final AppProperties.Otp cfg;
    private final SecureRandom random = new SecureRandom();

    public OtpService(OtpCodeRepository repo, EmailService email, AppProperties props) {
        this.repo = repo;
        this.email = email;
        this.cfg = props.otp();
    }

    /**
     * Generates, stores (hashed) and e-mails a fresh code, replacing any previous one.
     * A failure here must not mark the caller's transaction rollback-only (callers may handle the cooldown),
     * so the code is removed explicitly if the e-mail cannot be sent.
     */
    @Transactional(noRollbackFor = ApiException.class)
    public void issueAndSend(String address, OtpPurpose purpose) {
        repo.findFirstByEmailAndPurposeOrderByCreatedAtDesc(address, purpose).ifPresent(last -> {
            Duration since = Duration.between(last.getCreatedAt(), Instant.now());
            if (since.compareTo(cfg.resendCooldown()) < 0) {
                long wait = cfg.resendCooldown().minus(since).toSeconds() + 1;
                throw ApiException.tooManyRequests("OTP_COOLDOWN",
                        "Please wait " + wait + " seconds before requesting another code");
            }
        });
        repo.deleteAllFor(address, purpose);

        String code = generate();
        OtpCode otp = new OtpCode();
        otp.setEmail(address);
        otp.setPurpose(purpose);
        otp.setCodeHash(hash(address, purpose, code));
        otp.setExpiresAt(Instant.now().plus(cfg.ttl()));
        repo.save(otp);

        if (cfg.logCode()) {
            log.warn("[DEV] OTP for {} ({}): {}", address, purpose, code);
        }
        try {
            email.sendOtp(address, purpose, code, cfg.ttl());
        } catch (ApiException e) {
            repo.delete(otp);
            throw e;
        }
    }

    /**
     * Checks the code and consumes it. Runs in its own transaction so that failed-attempt counters
     * survive the exception that aborts the caller.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW, noRollbackFor = ApiException.class)
    public void verifyAndConsume(String address, OtpPurpose purpose, String code) {
        OtpCode otp = repo.findFirstByEmailAndPurposeAndConsumedFalseOrderByCreatedAtDesc(address, purpose)
                .orElseThrow(() -> ApiException.badRequest("INVALID_OTP", "Invalid or expired code"));
        if (otp.getExpiresAt().isBefore(Instant.now())) {
            throw ApiException.badRequest("OTP_EXPIRED", "This code has expired, please request a new one");
        }
        if (otp.getAttempts() >= cfg.maxAttempts()) {
            throw ApiException.tooManyRequests("OTP_TOO_MANY_ATTEMPTS",
                    "Too many wrong attempts, please request a new code");
        }
        boolean ok = MessageDigest.isEqual(
                hash(address, purpose, code).getBytes(StandardCharsets.UTF_8),
                otp.getCodeHash().getBytes(StandardCharsets.UTF_8));
        if (!ok) {
            otp.setAttempts(otp.getAttempts() + 1);
            repo.save(otp);
            throw ApiException.badRequest("INVALID_OTP", "Invalid or expired code");
        }
        otp.setConsumed(true);
        repo.save(otp);
    }

    private String generate() {
        int bound = (int) Math.pow(10, cfg.length());
        return String.format("%0" + cfg.length() + "d", random.nextInt(bound));
    }

    private static String hash(String address, OtpPurpose purpose, String code) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] out = md.digest((address.toLowerCase() + "|" + purpose + "|" + code).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(out);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
