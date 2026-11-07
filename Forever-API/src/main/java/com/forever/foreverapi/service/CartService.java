package com.forever.foreverapi.service;

import com.forever.foreverapi.common.security.ShopperRef;
import com.forever.foreverapi.model.dto.CartDtos.CartResponse;

/** Every operation is scoped to one shopper: a registered customer's cart or a guest session's cart, never both. */
public interface CartService {
    CartResponse get(ShopperRef shopper);
    CartResponse add(ShopperRef shopper, Long productId, String size, int quantity);
    CartResponse setQuantity(ShopperRef shopper, Long productId, String size, int quantity);
    CartResponse remove(ShopperRef shopper, Long itemId);
    void clear(ShopperRef shopper);
}
