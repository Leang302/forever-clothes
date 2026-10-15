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
    /** Renames a category and every product that uses it. */
    CategoryRow renameCategory(Long id, String name);
    /**
     * Moves all products of a category, or only {@code productIds}, to {@code targetId} (may be the same category)
     * and, when {@code targetSubCategoryId} is set, into that sub-category of it; otherwise they keep their own.
     */
    MoveProductsResult moveProducts(Long fromId, Long targetId, Long targetSubCategoryId, List<Long> productIds);
    /**
     * Deletes a category; its products are first moved to {@code moveToId} (required while it has any) and, when
     * {@code moveToSubId} is set, into that sub-category of it; otherwise they keep their own.
     */
    void deleteCategory(Long id, Long moveToId, Long moveToSubId);
    /** The managed category's exact name for {@code name} (case-insensitive), or a 400 if there is none. */
    String requireCategory(String name);
    List<SubCategoryRow> subCategories(Long categoryId);
    SubCategoryRow addSubCategory(Long categoryId, String name);
    /** Renames a sub-category and every product of its category that uses it. */
    SubCategoryRow renameSubCategory(Long id, String name);
    /** Deletes a sub-category; its products first move to {@code moveToId} (same category), required while it has any. */
    void deleteSubCategory(Long id, Long moveToId);
    /** The exact name of {@code name} among {@code category}'s sub-categories (case-insensitive), or a 400. */
    String requireSubCategory(String category, String name);
    List<CustomerRow> customers();
    Analytics analytics();
}
