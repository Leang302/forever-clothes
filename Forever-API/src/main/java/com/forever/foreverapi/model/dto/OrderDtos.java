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
            String shippingMethod) {
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
            Long userId,
            Instant createdAt,
            List<OrderStatus> nextStatuses) { // statuses an admin may move this order to next
    }

    public record UpdateStatusRequest(@NotNull OrderStatus status) {
    }
}
