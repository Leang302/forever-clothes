package com.forever.foreverapi.controller;

import com.forever.foreverapi.common.response.PageResponse;
import com.forever.foreverapi.model.dto.OrderDtos.OrderResponse;
import com.forever.foreverapi.model.dto.OrderDtos.UpdateStatusRequest;
import com.forever.foreverapi.model.entity.OrderStatus;
import com.forever.foreverapi.model.entity.PaymentMethod;
import com.forever.foreverapi.service.AdminSearchService;
import com.forever.foreverapi.service.OrderService;
import org.springframework.format.annotation.DateTimeFormat;
import java.time.LocalDate;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/admin/orders")
@Tag(name = "Admin - Orders", description = "ADMIN role only")
public class AdminOrderController {

    private final OrderService orders;
    private final AdminSearchService search;

    public AdminOrderController(OrderService orders, AdminSearchService search) {
        this.orders = orders;
        this.search = search;
    }

    @Operation(summary = "All orders with search (id, customer name/email/phone), filters and sorting",
            description = "sort: newest | oldest | total_desc | total_asc | status. from/to are inclusive dates (yyyy-MM-dd).")
    @GetMapping
    public PageResponse<OrderResponse> all(@RequestParam(required = false) String q,
                                           @RequestParam(required = false) OrderStatus status,
                                           @RequestParam(required = false) PaymentMethod paymentMethod,
                                           @RequestParam(required = false) Boolean paid,
                                           @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                           @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                                           @RequestParam(required = false) String coupon,
                                           @RequestParam(defaultValue = "newest") String sort,
                                           @RequestParam(defaultValue = "0") int page,
                                           @RequestParam(defaultValue = "20") int size) {
        return search.orders(q, status == null ? null : status.name(), paymentMethod == null ? null : paymentMethod.name(),
                paid, from, to, coupon, sort, page, size);
    }

    @Operation(summary = "Update order status (DELIVERED marks COD orders as paid; CANCELLED needs a reason, emailed to the customer)")
    @PatchMapping("/{id}/status")
    public OrderResponse updateStatus(@PathVariable Long id, @Valid @RequestBody UpdateStatusRequest req) {
        return orders.updateStatus(id, req.status(), req.reason());
    }
}
