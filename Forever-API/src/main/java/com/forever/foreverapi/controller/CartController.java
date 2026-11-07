package com.forever.foreverapi.controller;

import com.forever.foreverapi.common.security.ShopperRef;
import com.forever.foreverapi.model.dto.CartDtos.AddItemRequest;
import com.forever.foreverapi.model.dto.CartDtos.CartResponse;
import com.forever.foreverapi.model.dto.CartDtos.SetQuantityRequest;
import com.forever.foreverapi.service.CartService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/cart")
@Tag(name = "Cart", description = "Server-side shopping cart of the logged-in customer or the guest session (X-Guest-Session)")
public class CartController {

    private final CartService cart;

    public CartController(CartService cart) {
        this.cart = cart;
    }

    @Operation(summary = "Get my cart with totals")
    @GetMapping
    public CartResponse get(ShopperRef shopper) {
        return cart.get(shopper);
    }

    @Operation(summary = "Add a product/size to the cart (increments quantity if already there)")
    @PostMapping("/items")
    public CartResponse add(ShopperRef shopper, @Valid @RequestBody AddItemRequest req) {
        return cart.add(shopper, req.productId(), req.size(), req.quantity() == null ? 1 : req.quantity());
    }

    @Operation(summary = "Set the quantity of a cart line; 0 removes it")
    @PutMapping("/items")
    public CartResponse setQuantity(ShopperRef shopper, @Valid @RequestBody SetQuantityRequest req) {
        return cart.setQuantity(shopper, req.productId(), req.size(), req.quantity());
    }

    @Operation(summary = "Remove a cart line by id")
    @DeleteMapping("/items/{itemId}")
    public CartResponse remove(ShopperRef shopper, @PathVariable Long itemId) {
        return cart.remove(shopper, itemId);
    }

    @Operation(summary = "Empty the cart")
    @DeleteMapping
    public CartResponse clear(ShopperRef shopper) {
        cart.clear(shopper);
        return cart.get(shopper);
    }
}
