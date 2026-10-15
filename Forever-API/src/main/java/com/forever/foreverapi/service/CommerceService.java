package com.forever.foreverapi.service;

import com.forever.foreverapi.model.dto.CommerceDtos.*;
import java.math.BigDecimal;
import java.util.List;

public interface CommerceService {
    CheckoutOptions checkoutOptions();
    /** Pricing without the per-customer coupon limit check; prefer the overload with the user id. */
    Pricing price(BigDecimal itemsAmount, String couponCode, String shippingMethod);
    /** Delivery fee + coupon discount. Throws a 400 ApiException with a clear message if the coupon can't be used. */
    Pricing price(BigDecimal itemsAmount, String couponCode, String shippingMethod, Long userId);
    void reserve(Long productId, String size, int quantity);
    void restore(Long productId, String size, int quantity);
    void syncInventory(Long productId, List<String> sizes);
    List<InventoryRow> inventory();
    void setStock(Long productId, String size, int stock);
    List<CategoryRow> categories();
    CategoryRow addCategory(String name);
    void deleteCategory(Long id);
    List<CustomerRow> customers();
    Analytics analytics();
}
