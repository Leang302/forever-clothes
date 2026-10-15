package com.forever.foreverapi.controller;

import com.forever.foreverapi.common.response.PageResponse;
import com.forever.foreverapi.model.dto.CommerceDtos.*;
import com.forever.foreverapi.model.dto.OrderDtos.OrderResponse;
import com.forever.foreverapi.service.CommerceService;
import com.forever.foreverapi.service.OrderService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class CommerceController {
    private final CommerceService commerce;
    private final OrderService orders;
    public CommerceController(CommerceService commerce, OrderService orders) { this.commerce = commerce; this.orders = orders; }

    @GetMapping("/api/checkout/options") public CheckoutOptions checkoutOptions() { return commerce.checkoutOptions(); }

    @GetMapping("/api/admin/inventory") public List<InventoryRow> inventory() { return commerce.inventory(); }
    @PutMapping("/api/admin/inventory/{productId}/{size}") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void stock(@PathVariable Long productId, @PathVariable String size, @Valid @RequestBody StockRequest request) { commerce.setStock(productId, size, request.stock()); }

    @GetMapping("/api/admin/categories") public List<CategoryRow> categories() { return commerce.categories(); }
    @PostMapping("/api/admin/categories") @ResponseStatus(HttpStatus.CREATED)
    public CategoryRow category(@Valid @RequestBody NameRequest request) { return commerce.addCategory(request.name()); }
    @DeleteMapping("/api/admin/categories/{id}") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteCategory(@PathVariable Long id) { commerce.deleteCategory(id); }

    @GetMapping("/api/admin/customers") public List<CustomerRow> customers() { return commerce.customers(); }
    @GetMapping("/api/admin/customers/{id}/orders")
    public PageResponse<OrderResponse> customerOrders(@PathVariable Long id, @RequestParam(defaultValue="0") int page,
                                                       @RequestParam(defaultValue="20") int size) { return orders.forCustomer(id, page, size); }
    @GetMapping("/api/admin/analytics") public Analytics analytics() { return commerce.analytics(); }
}
