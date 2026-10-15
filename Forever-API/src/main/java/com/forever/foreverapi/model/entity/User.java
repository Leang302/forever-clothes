package com.forever.foreverapi.model.entity;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;

    @Column(unique = true)
    private String email;

    @Column(name = "password_hash")
    private String passwordHash;

    private String phone;

    @Enumerated(EnumType.STRING)
    private Role role = Role.USER;

    @Column(name = "email_verified")
    private boolean emailVerified;

    private boolean enabled = true;

    @Column(name = "created_at", updatable = false)
    private Instant createdAt = Instant.now();
}
