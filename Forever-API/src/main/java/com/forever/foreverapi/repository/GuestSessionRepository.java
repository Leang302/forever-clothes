package com.forever.foreverapi.repository;

import com.forever.foreverapi.model.entity.GuestSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.time.Instant;
import java.util.Optional;

public interface GuestSessionRepository extends JpaRepository<GuestSession, Long> {

    Optional<GuestSession> findByTokenHash(String tokenHash);

    /** Deletes expired sessions; their cart lines go with them (FK cascade), their orders stay (FK set null). */
    @Modifying
    @Query("delete from GuestSession g where g.expiresAt < :now")
    int deleteExpired(Instant now);
}
