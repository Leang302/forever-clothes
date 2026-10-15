package com.forever.foreverapi.service;

import com.forever.foreverapi.model.dto.CartDtos.CartResponse;

public interface CartService {
    CartResponse get(Long userId);
    CartResponse add(Long userId, Long productId, String size, int quantity);
    CartResponse setQuantity(Long userId, Long productId, String size, int quantity);
    CartResponse remove(Long userId, Long itemId);
    void clear(Long userId);
}
