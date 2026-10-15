package com.forever.foreverapi.repository;

import com.forever.foreverapi.model.entity.OtpCode;
import com.forever.foreverapi.model.entity.OtpPurpose;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.time.Instant;
import java.util.Optional;

public interface OtpCodeRepository extends JpaRepository<OtpCode, Long> {

    Optional<OtpCode> findFirstByEmailAndPurposeAndConsumedFalseOrderByCreatedAtDesc(String email, OtpPurpose purpose);

    Optional<OtpCode> findFirstByEmailAndPurposeOrderByCreatedAtDesc(String email, OtpPurpose purpose);

    @Modifying
    @Query("delete from OtpCode o where o.email = :email and o.purpose = :purpose")
    void deleteAllFor(String email, OtpPurpose purpose);

    @Modifying
    @Query("delete from OtpCode o where o.expiresAt < :cutoff")
    int deleteExpiredBefore(Instant cutoff);
}
