package com.forever.foreverapi.repository;

import com.forever.foreverapi.model.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

import com.forever.foreverapi.model.entity.Role;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmailIgnoreCase(String email);

    boolean existsByEmailIgnoreCase(String email);

    long countByRole(Role role);
}
