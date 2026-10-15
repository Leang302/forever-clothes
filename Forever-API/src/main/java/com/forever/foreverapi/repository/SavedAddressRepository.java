package com.forever.foreverapi.repository;

import com.forever.foreverapi.model.entity.SavedAddress;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface SavedAddressRepository extends JpaRepository<SavedAddress, Long> {
    List<SavedAddress> findByUserIdOrderByCreatedAtDesc(Long userId);
}
