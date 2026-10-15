package com.forever.foreverapi.mapper;

import com.forever.foreverapi.util.MediaUrls;
import com.forever.foreverapi.model.dto.ProductDtos.ProductResponse;
import com.forever.foreverapi.model.entity.Product;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class ProductMapper {

    private final MediaUrls media;

    public ProductMapper(MediaUrls media) {
        this.media = media;
    }

    public ProductResponse toResponse(Product p) {
        return new ProductResponse(p.getId(), p.getName(), p.getDescription(), p.getPrice(), p.getCategory(),
                p.getSubCategory(), List.copyOf(p.getSizes()), p.getImages().stream().map(media::url).toList(),
                p.isBestseller(), p.isActive(), p.getCreatedAt());
    }
}
