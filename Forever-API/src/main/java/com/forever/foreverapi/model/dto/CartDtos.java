package com.forever.foreverapi.model.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.List;

public final class CartDtos {

    private CartDtos() {
    }

    public record AddItemRequest(
            @NotNull Long productId,
            @NotBlank String size,
            @Min(1) @Max(99) Integer quantity) {
    }

    public record SetQuantityRequest(
            @NotNull Long productId,
            @NotBlank String size,
            @NotNull @Min(0) @Max(99) Integer quantity) {
    }

    public record CartLine(Long id, Long productId, String name, BigDecimal price, String image, String size,
                           int quantity, BigDecimal lineTotal) {
    }

    public record CartResponse(List<CartLine> items, int itemCount, BigDecimal subtotal, BigDecimal deliveryFee,
                               BigDecimal total, String currency) {
    }
}
