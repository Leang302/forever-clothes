package com.forever.foreverapi.model.dto;

import java.math.BigDecimal;
import java.util.Map;

public final class AdminDtos {

    private AdminDtos() {
    }

    /** Numbers for the admin dashboard. `revenue` excludes cancelled orders. */
    public record StatsResponse(
            long activeProducts,
            long hiddenProducts,
            long customers,
            long totalOrders,
            Map<String, Long> ordersByStatus,
            BigDecimal revenue) {
    }
}
