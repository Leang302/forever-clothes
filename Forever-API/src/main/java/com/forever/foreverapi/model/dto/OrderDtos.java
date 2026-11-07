package com.forever.foreverapi.model.dto;

import com.forever.foreverapi.model.entity.OrderStatus;
import com.forever.foreverapi.model.entity.PaymentMethod;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

public final class OrderDtos {

    private OrderDtos() {
    }

    public record AddressDto(
            @NotBlank @Size(max = 80) String firstName,
            @NotBlank @Size(max = 80) String lastName,
            @NotBlank @Email String email,
            @NotBlank @Size(max = 200) String street,
            @NotBlank @Size(max = 100) String city,
            @NotBlank @Size(max = 100) String state,
            @NotBlank @Size(max = 20) String zipcode,
            @NotBlank @Size(max = 100) String country,
            @NotBlank @Size(max = 40) String phone) {
    }

    public record PlaceOrderRequest(
            @NotNull @Valid AddressDto address,
            @NotNull PaymentMethod paymentMethod,
            String couponCode,
            String shippingMethod,
            // Cart lines to buy; empty or missing means the whole cart. Unselected lines stay in the cart.
            List<Long> cartItemIds,
            // Client-generated key for this checkout attempt (e.g. a UUID minted once per "place order" tap and
            // reused on retry). Replaying the same key returns the order already created by the first attempt
            // instead of creating a duplicate. Optional; omitting it disables the duplicate-submission guard.
            @Size(max = 64) String idempotencyKey) {
    }

    public record OrderItemResponse(Long productId, String name, String image, BigDecimal price, String size,
                                    int quantity) {
    }

    public record OrderResponse(
            Long id,
            OrderStatus status,
            PaymentMethod paymentMethod,
            boolean paid,
            BigDecimal itemsAmount,
            BigDecimal deliveryFee,
            BigDecimal discount,
            String couponCode,
            String shippingMethod,
            BigDecimal total,
            AddressDto address,
            List<OrderItemResponse> items,
            Long userId, // null for a guest order
            Instant createdAt,
            List<OrderStatus> nextStatuses, // statuses an admin may move this order to next
            String cancelReason,
            String cancelledBy, // ADMIN or CUSTOMER when cancelled
            boolean guest,
            // Only in the response to the guest who placed the order: send it as X-Order-Access to
            // /api/guest-orders/{id}/... to view the confirmation / finish paying. Null everywhere else.
            String guestAccessToken) {

        public OrderResponse withGuestAccessToken(String token) {
            return new OrderResponse(id, status, paymentMethod, paid, itemsAmount, deliveryFee, discount, couponCode,
                    shippingMethod, total, address, items, userId, createdAt, nextStatuses, cancelReason, cancelledBy,
                    guest, token);
        }
    }

    /** {@code reason} is required when cancelling; it is emailed to the customer and shown on their order. */
    public record UpdateStatusRequest(@NotNull OrderStatus status,
                                      @Size(max = 500, message = "Reason must be 500 characters or fewer") String reason) {
    }
}
