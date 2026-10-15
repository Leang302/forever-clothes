package com.forever.foreverapi.model.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

public final class CommerceDtos {
    private CommerceDtos() {}
    public record ShippingOption(String code, String name, BigDecimal fee, String estimate) {}
    public record CheckoutOptions(List<ShippingOption> shippingMethods) {}
    public record InventoryRow(Long productId, String productName, String size, int stock, boolean lowStock) {}
    public record StockRequest(@NotNull @Min(0) Integer stock) {}
    public record CategoryRow(Long id, String name, boolean active, long productCount, long activeProductCount) {}
    public record NameRequest(@NotBlank String name) {}

    /**
     * Admin view of a coupon. {@code status} is one of ACTIVE, SCHEDULED, EXPIRED, USED_UP, INACTIVE.
     * {@code timesUsed} / {@code totalDiscount} count non-cancelled orders that used the code.
     */
    public record CouponRow(Long id, String code, String description, String discountType, Integer percentOff,
                            BigDecimal amountOff, BigDecimal maxDiscount, BigDecimal minSubtotal, Instant startsAt,
                            Instant expiresAt, Integer usageLimit, Integer perCustomerLimit, boolean active,
                            long timesUsed, BigDecimal totalDiscount, String status, Instant createdAt) {}

    /** Create/update a coupon. PERCENT needs percentOff (maxDiscount optional); FIXED needs amountOff. */
    public record CouponRequest(
            @NotBlank @Size(max = 30) @Pattern(regexp = "^[A-Za-z0-9_-]+$", message = "Code may only contain letters, digits, - and _") String code,
            @Size(max = 200) String description,
            @Pattern(regexp = "PERCENT|FIXED", message = "Discount type must be PERCENT or FIXED") String discountType,
            @Min(1) @Max(90) Integer percentOff,
            @DecimalMin(value = "0.01", message = "Amount off must be greater than 0") BigDecimal amountOff,
            @DecimalMin(value = "0.01", message = "Max discount must be greater than 0") BigDecimal maxDiscount,
            @DecimalMin(value = "0", message = "Minimum subtotal cannot be negative") BigDecimal minSubtotal,
            Instant startsAt,
            Instant expiresAt,
            @Min(value = 1, message = "Usage limit must be at least 1") Integer usageLimit,
            @Min(value = 1, message = "Per-customer limit must be at least 1") Integer perCustomerLimit,
            Boolean active) {}

    /** Storefront preview of a coupon before placing the order. */
    public record CouponCheckRequest(@NotBlank String code, @NotNull @DecimalMin("0") BigDecimal subtotal) {}
    public record CouponPreview(String code, String description, String discountType, BigDecimal discount, String summary) {}

    public record CustomerRow(Long id, String name, String email, String phone, long orderCount, BigDecimal totalSpent, Instant createdAt) {}
    public record RevenuePoint(LocalDate day, BigDecimal revenue) {}
    public record TopProduct(Long productId, String name, long quantity, BigDecimal revenue) {}
    public record Analytics(List<RevenuePoint> revenueByDay, List<TopProduct> topProducts, long lowStockCount) {}
    public record Pricing(BigDecimal discount, String couponCode, BigDecimal deliveryFee, String shippingMethod) {}
}
