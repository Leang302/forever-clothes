package com.forever.foreverapi.service;

import com.forever.foreverapi.model.dto.CustomerDtos.AddressRequest;
import com.forever.foreverapi.model.dto.CustomerDtos.AddressResponse;
import com.forever.foreverapi.model.dto.ProductDtos.ProductResponse;
import java.util.List;

public interface CustomerService {
    List<ProductResponse> wishlist(Long userId);
    ProductResponse addWishlist(Long userId, Long productId);
    void removeWishlist(Long userId, Long productId);
    List<AddressResponse> addresses(Long userId);
    AddressResponse addAddress(Long userId, AddressRequest request);
    void deleteAddress(Long userId, Long addressId);
}
