package com.forever.foreverapi.repository;

import com.forever.foreverapi.model.entity.CartItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;

public interface CartItemRepository extends JpaRepository<CartItem, Long> {

    @Query("select c from CartItem c join fetch c.product where c.user.id = :userId order by c.id")
    List<CartItem> findAllByUser(Long userId);

    Optional<CartItem> findByUserIdAndProductIdAndSize(Long userId, Long productId, String size);

    Optional<CartItem> findByIdAndUserId(Long id, Long userId);

    @Modifying
    @Query("delete from CartItem c where c.user.id = :userId")
    void deleteAllByUser(Long userId);
}
