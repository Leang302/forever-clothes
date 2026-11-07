package com.forever.foreverapi.service;

import com.forever.foreverapi.common.security.ShopperRef;
import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.model.dto.ProductDtos.ProductForm;
import com.forever.foreverapi.model.dto.ProductDtos.ProductResponse;
import com.forever.foreverapi.model.entity.Product;
import com.forever.foreverapi.repository.ProductRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** FIX-001: public product responses carry real per-size inventory, and the cart enforces it. Rolled back. */
@SpringBootTest
@Transactional
class ProductStockTest {

    @Autowired
    ProductService productService;
    @Autowired
    CartService cart;
    @Autowired
    AuthService auth;
    @Autowired
    CommerceService commerce;
    @Autowired
    ProductRepository products;
    @Autowired
    JdbcClient db;
    @Autowired
    com.forever.foreverapi.repository.UserRepository users;
    @Autowired
    GuestSessionService guestSessions;

    private com.forever.foreverapi.TestShoppers shoppers() {
        return new com.forever.foreverapi.TestShoppers(users, guestSessions);
    }

    private Product product() {
        return products.findAll().stream().filter(Product::isActive).findFirst().orElseThrow();
    }

    private int dbStock(Long productId, String size) {
        return db.sql("select stock from product_inventory where product_id = :id and size = :size")
                .param("id", productId).param("size", size).query(Integer.class).single();
    }

    @Test
    void publicProductResponseMirrorsTheInventoryTable() {
        Product p = product();
        String size = p.getSizes().getFirst();
        commerce.setStock(p.getId(), size, 3);

        ProductResponse res = productService.get(p.getId());

        assertEquals(3, res.stock().get(size));
        for (String s : p.getSizes()) assertEquals(dbStock(p.getId(), s), res.stock().get(s));
        assertThat(res.stock().keySet()).containsExactlyElementsOf(p.getSizes()); // same order as `sizes`
    }

    @Test
    void productIsOutOfStockOnlyWhenEverySizeIsEmpty() {
        Product p = product();
        p.getSizes().forEach(s -> commerce.setStock(p.getId(), s, 0));
        assertFalse(productService.get(p.getId()).inStock());

        commerce.setStock(p.getId(), p.getSizes().getFirst(), 1);
        assertTrue(productService.get(p.getId()).inStock());
    }

    @Test
    void listingEndpointsCarryStockToo() {
        assertThat(productService.latest(5)).allSatisfy(r -> assertThat(r.stock()).isNotEmpty());
        assertThat(productService.search(null, null, null, null, 0, 5, false).content())
                .allSatisfy(r -> assertThat(r.stock().keySet()).containsExactlyElementsOf(r.sizes()));
    }

    @Test
    void cartRejectsQuantitiesBeyondStock() {
        ShopperRef user = shoppers().customer();
        Product p = product();
        String size = p.getSizes().getFirst();
        commerce.setStock(p.getId(), size, 2);

        var res = cart.add(user, p.getId(), size, 2);
        assertEquals(2, res.items().getFirst().stock());

        ApiException more = assertThrows(ApiException.class, () -> cart.add(user, p.getId(), size, 1));
        assertEquals("OUT_OF_STOCK", more.getCode());
        ApiException set = assertThrows(ApiException.class, () -> cart.setQuantity(user, p.getId(), size, 3));
        assertEquals("OUT_OF_STOCK", set.getCode());

        commerce.setStock(p.getId(), size, 0);
        ShopperRef other = shoppers().guest().ref(); // a guest cart is held to stock the same way
        ApiException none = assertThrows(ApiException.class, () -> cart.add(other, p.getId(), size, 1));
        assertThat(none.getMessage()).contains("out of stock");
    }

    @Test
    void productFormSetsStockStatusAndAcceptsImageUrls() {
        var form = new ProductForm("Test tee", "A test product", new BigDecimal("12.50"), "Men", "Winterwear",
                List.of("S,M"), false, null, List.of("https://example.com/a.jpg"), false, 7);

        ProductResponse created = productService.create(form);

        assertFalse(created.active());
        assertEquals(List.of("https://example.com/a.jpg"), created.images());
        assertEquals(7, created.stock().get("S"));
        assertEquals(7, created.stock().get("M"));

        var keepStock = new ProductForm("Test tee 2", "A test product", new BigDecimal("12.50"), "Men", "Winterwear",
                List.of("S,M,L"), false, null, null, true, null);
        ProductResponse updated = productService.update(created.id(), keepStock);
        assertTrue(updated.active());
        assertEquals(7, updated.stock().get("S")); // omitted stock keeps per-size inventory
        assertEquals(20, updated.stock().get("L")); // a new size starts at the default
        assertEquals(List.of("https://example.com/a.jpg"), updated.images()); // no new images: unchanged
    }

    @Test
    void imageUrlsMustBeHttp() {
        var form = new ProductForm("Bad", "x", new BigDecimal("1.00"), "Men", "Winterwear", List.of("S"), false,
                null, List.of("javascript:alert(1)"), true, null);
        ApiException e = assertThrows(ApiException.class, () -> productService.create(form));
        assertEquals("INVALID_IMAGE_URL", e.getCode());
    }
}
