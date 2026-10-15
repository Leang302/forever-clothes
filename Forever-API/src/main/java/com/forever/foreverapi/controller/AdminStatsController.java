package com.forever.foreverapi.controller;

import com.forever.foreverapi.model.dto.AdminDtos.StatsResponse;
import com.forever.foreverapi.service.AdminStatsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/stats")
@Tag(name = "Admin - Dashboard", description = "ADMIN role only")
public class AdminStatsController {

    private final AdminStatsService stats;

    public AdminStatsController(AdminStatsService stats) {
        this.stats = stats;
    }

    @Operation(summary = "Dashboard numbers: products, customers, orders by status, revenue")
    @GetMapping
    public StatsResponse stats() {
        return stats.stats();
    }
}
