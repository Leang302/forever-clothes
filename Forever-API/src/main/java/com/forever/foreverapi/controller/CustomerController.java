package com.forever.foreverapi.controller;

import com.forever.foreverapi.common.security.AuthUser;
import com.forever.foreverapi.model.dto.CustomerDtos.AddressRequest;
import com.forever.foreverapi.model.dto.CustomerDtos.AddressResponse;
import com.forever.foreverapi.model.dto.ProductDtos.ProductResponse;
import com.forever.foreverapi.service.CustomerService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class CustomerController {
    private final CustomerService customers;
    public CustomerController(CustomerService customers) { this.customers = customers; }

    @GetMapping("/api/wishlist")
    public List<ProductResponse> wishlist(@AuthenticationPrincipal AuthUser user) { return customers.wishlist(user.id()); }
    @PostMapping("/api/wishlist/{productId}")
    @ResponseStatus(HttpStatus.CREATED)
    public ProductResponse addWishlist(@AuthenticationPrincipal AuthUser user, @PathVariable Long productId) {
        return customers.addWishlist(user.id(), productId);
    }
    @DeleteMapping("/api/wishlist/{productId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeWishlist(@AuthenticationPrincipal AuthUser user, @PathVariable Long productId) {
        customers.removeWishlist(user.id(), productId);
    }
    @GetMapping("/api/users/me/addresses")
    public List<AddressResponse> addresses(@AuthenticationPrincipal AuthUser user) { return customers.addresses(user.id()); }
    @PostMapping("/api/users/me/addresses")
    @ResponseStatus(HttpStatus.CREATED)
    public AddressResponse addAddress(@AuthenticationPrincipal AuthUser user, @Valid @RequestBody AddressRequest request) {
        return customers.addAddress(user.id(), request);
    }
    @DeleteMapping("/api/users/me/addresses/{addressId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteAddress(@AuthenticationPrincipal AuthUser user, @PathVariable Long addressId) {
        customers.deleteAddress(user.id(), addressId);
    }
}
