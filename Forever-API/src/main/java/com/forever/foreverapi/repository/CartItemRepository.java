package com.forever.foreverapi.repository;

import com.forever.foreverapi.common.security.ShopperRef;
import com.forever.foreverapi.model.entity.CartItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;

public interface CartItemRepository extends JpaRepository<CartItem, Long> {

    @Query("select c from CartItem c join fetch c.product where c.user.id = :userId order by c.id")
    List<CartItem> findAllByUser(Long userId);

    @Query("select c from CartItem c join fetch c.product where c.guestSessionId = :sessionId order by c.id")
    List<CartItem> findAllByGuestSession(Long sessionId);

    Optional<CartItem> findByUserIdAndProductIdAndSize(Long userId, Long productId, String size);

    Optional<CartItem> findByGuestSessionIdAndProductIdAndSize(Long guestSessionId, Long productId, String size);

    Optional<CartItem> findByIdAndUserId(Long id, Long userId);

    Optional<CartItem> findByIdAndGuestSessionId(Long id, Long guestSessionId);

    @Modifying
    @Query("delete from CartItem c where c.user.id = :userId")
    void deleteAllByUser(Long userId);

    @Modifying
    @Query("delete from CartItem c where c.guestSessionId = :sessionId")
    void deleteAllByGuestSession(Long sessionId);

    // Owner-dispatching helpers: every cart query is scoped to exactly one shopper.

    default List<CartItem> findAllFor(ShopperRef s) {
        return s.isGuest() ? findAllByGuestSession(s.guestSessionId()) : findAllByUser(s.userId());
    }

    default Optional<CartItem> findLine(ShopperRef s, Long productId, String size) {
        return s.isGuest() ? findByGuestSessionIdAndProductIdAndSize(s.guestSessionId(), productId, size)
                : findByUserIdAndProductIdAndSize(s.userId(), productId, size);
    }

    default Optional<CartItem> findLineById(ShopperRef s, Long id) {
        return s.isGuest() ? findByIdAndGuestSessionId(id, s.guestSessionId()) : findByIdAndUserId(id, s.userId());
    }

    default void deleteAllFor(ShopperRef s) {
        if (s.isGuest()) deleteAllByGuestSession(s.guestSessionId());
        else deleteAllByUser(s.userId());
    }
}
