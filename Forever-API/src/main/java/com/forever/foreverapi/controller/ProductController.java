package com.forever.foreverapi.controller;

import com.forever.foreverapi.common.response.PageResponse;
import com.forever.foreverapi.model.dto.ProductDtos.FilterOptions;
import com.forever.foreverapi.model.dto.ProductDtos.ProductResponse;
import com.forever.foreverapi.service.ProductService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/products")
@Tag(name = "Products", description = "Public catalogue")
@SecurityRequirements
public class ProductController {

    private final ProductService products;

    public ProductController(ProductService products) {
        this.products = products;
    }

    @Operation(summary = "Search / filter / sort / paginate products",
            description = "`category` and `subCategory` can be repeated (multi-select). "
                    + "`sort`: relevant | price_asc | price_desc | newest.")
    @GetMapping
    public PageResponse<ProductResponse> list(
            @Parameter(description = "Name contains") @RequestParam(required = false) String q,
            @RequestParam(required = false) List<String> category,
            @RequestParam(required = false) List<String> subCategory,
            @RequestParam(defaultValue = "relevant") String sort,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return products.search(q, category, subCategory, sort, page, size, false);
    }

    @Operation(summary = "Available categories, sub-categories and sort options")
    @GetMapping("/filters")
    public FilterOptions filters() {
        return products.filters();
    }

    @Operation(summary = "Latest collection (home page)")
    @GetMapping("/latest")
    public List<ProductResponse> latest(@RequestParam(defaultValue = "10") int limit) {
        return products.latest(limit);
    }

    @Operation(summary = "Best sellers (home page)")
    @GetMapping("/bestsellers")
    public List<ProductResponse> bestsellers(@RequestParam(defaultValue = "5") int limit) {
        return products.bestsellers(limit);
    }

    @Operation(summary = "Product details")
    @GetMapping("/{id}")
    public ProductResponse get(@PathVariable Long id) {
        return products.get(id);
    }

    @Operation(summary = "Related products (same category + sub-category)")
    @GetMapping("/{id}/related")
    public List<ProductResponse> related(@PathVariable Long id, @RequestParam(defaultValue = "5") int limit) {
        return products.related(id, limit);
    }
}
