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
    @PutMapping("/api/admin/categories/{id}")
    public CategoryRow renameCategory(@PathVariable Long id, @Valid @RequestBody NameRequest request) { return commerce.renameCategory(id, request.name()); }
    @PostMapping("/api/admin/categories/{id}/move-products")
    public MoveProductsResult moveProducts(@PathVariable Long id, @Valid @RequestBody MoveProductsRequest request) {
        return commerce.moveProducts(id, request.targetId(), request.targetSubCategoryId(), request.productIds());
    }
    @DeleteMapping("/api/admin/categories/{id}") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteCategory(@PathVariable Long id, @RequestParam(required = false) Long moveTo,
                               @RequestParam(required = false) Long moveToSub) { commerce.deleteCategory(id, moveTo, moveToSub); }

    @GetMapping("/api/admin/categories/{id}/sub-categories")
    public List<SubCategoryRow> subCategories(@PathVariable Long id) { return commerce.subCategories(id); }
    @PostMapping("/api/admin/categories/{id}/sub-categories") @ResponseStatus(HttpStatus.CREATED)
    public SubCategoryRow addSubCategory(@PathVariable Long id, @Valid @RequestBody NameRequest request) { return commerce.addSubCategory(id, request.name()); }
    @PutMapping("/api/admin/sub-categories/{id}")
    public SubCategoryRow renameSubCategory(@PathVariable Long id, @Valid @RequestBody NameRequest request) { return commerce.renameSubCategory(id, request.name()); }
    @DeleteMapping("/api/admin/sub-categories/{id}") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteSubCategory(@PathVariable Long id, @RequestParam(required = false) Long moveTo) { commerce.deleteSubCategory(id, moveTo); }

    @GetMapping("/api/admin/customers") public List<CustomerRow> customers() { return commerce.customers(); }
    @GetMapping("/api/admin/customers/{id}/orders")
    public PageResponse<OrderResponse> customerOrders(@PathVariable Long id, @RequestParam(defaultValue="0") int page,
                                                       @RequestParam(defaultValue="20") int size) { return orders.forCustomer(id, page, size); }
    @GetMapping("/api/admin/analytics") public Analytics analytics() { return commerce.analytics(); }
}
