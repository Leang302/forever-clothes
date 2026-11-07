package com.forever.foreverapi.job;

import com.forever.foreverapi.service.GuestSessionService;
import com.forever.foreverapi.repository.OtpCodeRepository;
import org.springframework.jdbc.core.simple.JdbcClient;
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
    private final JdbcClient db;
    private final GuestSessionService guestSessions;

    public TokenCleanupJob(OtpCodeRepository otps, RefreshTokenRepository refreshTokens, JdbcClient db,
                           GuestSessionService guestSessions) {
        this.otps = otps;
        this.refreshTokens = refreshTokens;
        this.db = db;
        this.guestSessions = guestSessions;
    }

    @Scheduled(cron = "0 0 * * * *")
    @Transactional
    public void purge() {
        Instant cutoff = Instant.now().minus(1, ChronoUnit.DAYS);
        int o = otps.deleteExpiredBefore(cutoff);
        int r = refreshTokens.deleteExpiredBefore(cutoff);
        int s = guestSessions.purgeExpired();
        int g = purgeRetiredGuestAccounts();
        if (o + r + s + g > 0) {
            log.info("Purged {} expired OTPs, {} expired refresh tokens, {} expired guest cart sessions and {} retired guest accounts",
                    o, r, s, g);
        }
    }

    /**
     * Removes the throwaway GUEST user accounts the old guest flow created (guests now use anonymous cart sessions).
     * Their orders were detached by V14 and are kept as guest orders; anything still referencing one is skipped.
     */
    int purgeRetiredGuestAccounts() {
        return db.sql("delete from users u where u.role = 'GUEST'"
                        + " and not exists (select 1 from orders o where o.user_id = u.id)")
                .update();
    }
}
