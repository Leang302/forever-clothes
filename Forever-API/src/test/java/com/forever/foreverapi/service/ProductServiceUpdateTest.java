package com.forever.foreverapi.service;

import com.forever.foreverapi.model.dto.ProductDtos.ProductForm;
import com.forever.foreverapi.model.dto.ProductDtos.ProductResponse;
import com.forever.foreverapi.model.entity.Product;
import com.forever.foreverapi.repository.ProductRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Runs against the dev database (rolled back afterwards): editing a persisted product must not blow up. */
@SpringBootTest
@Transactional
class ProductServiceUpdateTest {

    @Autowired
    ProductService service;

    @Autowired
    ProductRepository repo;

    private ProductForm form(List<String> sizes, boolean bestseller) {
        return new ProductForm("Renamed", "New description", new BigDecimal("355.00"), "Men", "Winterwear",
                sizes, bestseller, null);
    }

    @Test
    void updatingFieldsAndSizesKeepsExistingImages() {
        Product existing = repo.findAll().getFirst();
        List<String> imagesBefore = List.copyOf(existing.getImages());

        ProductResponse updated = service.update(existing.getId(), form(List.of("S", "M", "S"), true));

        assertEquals("Renamed", updated.name());
        assertEquals(new BigDecimal("355.00"), updated.price());
        assertEquals(List.of("S", "M"), updated.sizes()); // de-duplicated, order kept
        assertTrue(updated.bestseller());
        assertEquals(imagesBefore.size(), updated.images().size()); // no new upload -> images untouched
    }

    @Test
    void bestsellerIsOptionalAndDefaultsToFalse() {
        Product existing = repo.findAll().getFirst();
        ProductResponse updated = service.update(existing.getId(), form(List.of("L"), false));
        assertEquals(false, updated.bestseller());
        assertEquals(List.of("L"), updated.sizes());
    }
}
