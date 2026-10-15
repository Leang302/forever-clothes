package com.forever.foreverapi.repository;

import com.forever.foreverapi.model.entity.Order;
import com.forever.foreverapi.model.entity.OrderStatus;
import com.forever.foreverapi.model.entity.PaymentMethod;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import org.springframework.data.jpa.repository.Query;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

public interface OrderRepository extends JpaRepository<Order, Long> {

    Page<Order> findByUserId(Long userId, Pageable pageable);

    // Unpaid online (QR) orders stay hidden from the customer until the payment is confirmed.
    @Query("select o from Order o where o.user.id = :userId and (o.paymentMethod = :cod or o.paid = true)")
    Page<Order> findCustomerVisibleByUserId(Long userId, PaymentMethod cod, Pageable pageable);

    Optional<Order> findByIdAndUserId(Long id, Long userId);

    Page<Order> findByStatus(OrderStatus status, Pageable pageable);

    @Query("select o.status, count(o) from Order o group by o.status")
    List<Object[]> countGroupedByStatus();

    @Query("select coalesce(sum(o.total), 0) from Order o where o.status <> :excluded")
    BigDecimal sumTotalExcluding(OrderStatus excluded);
}
