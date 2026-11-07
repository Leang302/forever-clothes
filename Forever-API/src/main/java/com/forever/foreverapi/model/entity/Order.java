package com.forever.foreverapi.model.entity;

import com.forever.foreverapi.model.entity.User;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.BatchSize;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Embedded;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "orders")
@Getter
@Setter
@NoArgsConstructor
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** The registered customer; null for a guest order (which is never attached to an account later). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    /** Guest cart session the order was placed from; cleared when that session expires. Not an access grant. */
    @Column(name = "guest_session_id")
    private Long guestSessionId;

    /** Secret material for the guest's own order-access token (see GuestOrderAccess), and its expiry. */
    @Column(name = "guest_access_nonce")
    private String guestAccessNonce;

    @Column(name = "guest_access_expires_at")
    private Instant guestAccessExpiresAt;

    @Enumerated(EnumType.STRING)
    private OrderStatus status = OrderStatus.ORDER_PLACED;

    @Enumerated(EnumType.STRING)
    @Column(name = "payment_method")
    private PaymentMethod paymentMethod;

    private boolean paid;

    @Column(name = "items_amount")
    private BigDecimal itemsAmount;

    @Column(name = "delivery_fee")
    private BigDecimal deliveryFee;

    private BigDecimal total;

    private BigDecimal discount = BigDecimal.ZERO;

    @Column(name = "coupon_code")
    private String couponCode;

    @Column(name = "shipping_method")
    private String shippingMethod = "STANDARD";

    @Column(name = "cancel_reason")
    private String cancelReason;

    /** ADMIN or CUSTOMER, set when the order is cancelled. */
    @Column(name = "cancelled_by")
    private String cancelledBy;

    /** MD5 of the KHQR string the customer was asked to scan; Bakong looks the payment up by it. */
    @Column(name = "khqr_md5")
    private String khqrMd5;

    /** The KHQR payload shown to the customer and when it stops being payable. */
    @Column(name = "khqr_qr", columnDefinition = "text")
    private String khqrQr;

    @Column(name = "khqr_expires_at")
    private Instant khqrExpiresAt;

    /** Client-generated key for one checkout submission; lets a retried/double-tapped request be replayed safely. */
    @Column(name = "idempotency_key")
    private String idempotencyKey;

    /** SHA-256 of the submitted checkout details, so a key reused with different details is rejected. */
    @Column(name = "idempotency_fingerprint")
    private String idempotencyFingerprint;

    @Embedded
    private ShippingAddress address;

    @Column(name = "created_at", updatable = false)
    private Instant createdAt = Instant.now();

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("id")
    @BatchSize(size = 50)
    private List<OrderItem> items = new ArrayList<>();

    public void addItem(OrderItem item) {
        item.setOrder(this);
        items.add(item);
    }
}
