package com.forever.foreverapi.job;

import com.forever.foreverapi.repository.OtpCodeRepository;
import com.forever.foreverapi.repository.RefreshTokenRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

@Slf4j
@Component
public class TokenCleanupJob {

    private final OtpCodeRepository otps;
    private final RefreshTokenRepository refreshTokens;

    public TokenCleanupJob(OtpCodeRepository otps, RefreshTokenRepository refreshTokens) {
        this.otps = otps;
        this.refreshTokens = refreshTokens;
    }

    @Scheduled(cron = "0 0 * * * *")
    @Transactional
    public void purge() {
        Instant cutoff = Instant.now().minus(1, ChronoUnit.DAYS);
        int o = otps.deleteExpiredBefore(cutoff);
        int r = refreshTokens.deleteExpiredBefore(cutoff);
        if (o + r > 0) {
            log.info("Purged {} expired OTPs and {} expired refresh tokens", o, r);
        }
    }
}
