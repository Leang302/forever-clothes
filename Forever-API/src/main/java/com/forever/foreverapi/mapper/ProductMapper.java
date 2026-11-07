package com.forever.foreverapi.mapper;

import com.forever.foreverapi.util.MediaUrls;
import com.forever.foreverapi.model.dto.ProductDtos.ProductResponse;
import com.forever.foreverapi.model.entity.Product;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
public class ProductMapper {

    private final MediaUrls media;
    private final JdbcClient db;

    public ProductMapper(MediaUrls media, JdbcClient db) {
        this.media = media;
        this.db = db;
    }

    public ProductResponse toResponse(Product p) {
        return toResponse(p, stockFor(List.of(p.getId())).getOrDefault(p.getId(), Map.of()));
    }

    /** Maps a page/list with one inventory query instead of one per product. */
    public List<ProductResponse> toResponses(Collection<Product> products) {
        Map<Long, Map<String, Integer>> stock = stockFor(products.stream().map(Product::getId).toList());
        return products.stream().map(p -> toResponse(p, stock.getOrDefault(p.getId(), Map.of()))).toList();
    }

    private ProductResponse toResponse(Product p, Map<String, Integer> stockBySize) {
        Map<String, Integer> stock = new LinkedHashMap<>();
        for (String size : p.getSizes()) stock.put(size, stockBySize.getOrDefault(size, 0));
        boolean inStock = p.isActive() && stock.values().stream().anyMatch(q -> q > 0);
        return new ProductResponse(p.getId(), p.getName(), p.getDescription(), p.getPrice(), p.getCategory(),
                p.getSubCategory(), List.copyOf(p.getSizes()), p.getImages().stream().map(media::url).toList(),
                p.isBestseller(), p.isActive(), p.getCreatedAt(), stock, inStock);
    }

    /** product id -> (size -> units left). Products with no inventory rows are absent. */
    public Map<Long, Map<String, Integer>> stockFor(Collection<Long> ids) {
        if (ids.isEmpty()) return Map.of();
        Map<Long, Map<String, Integer>> out = new HashMap<>();
        db.sql("select product_id, size, stock from product_inventory where product_id in (:ids)")
                .param("ids", ids)
                .query(rs -> {
                    out.computeIfAbsent(rs.getLong(1), k -> new HashMap<>()).put(rs.getString(2), rs.getInt(3));
                });
        return out;
    }
}
