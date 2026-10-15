package com.forever.foreverapi.model.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import org.springframework.web.multipart.MultipartFile;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

public final class ProductDtos {

    private ProductDtos() {
    }

    public record ProductResponse(
            Long id,
            String name,
            String description,
            BigDecimal price,
            String category,
            String subCategory,
            List<String> sizes,
            @Schema(description = "Absolute image URLs, first one is the cover") List<String> images,
            @Schema(description = "Defaults to false when omitted") Boolean bestseller,
            boolean active,
            Instant createdAt) {
    }

    public record FilterOptions(List<String> categories, List<String> subCategories, List<String> sortOptions) {
    }

    /** Multipart form for creating a product (images are files). */
    public record ProductForm(
            @NotBlank @Size(max = 200) String name,
            @NotBlank String description,
            @NotNull @DecimalMin(value = "0.01") BigDecimal price,
            @NotBlank @Size(max = 40) String category,
            @NotBlank @Size(max = 40) String subCategory,
            @Schema(description = "Repeat the field or comma-separate, e.g. S,M,L") @NotEmpty List<String> sizes,
            @Schema(description = "Defaults to false when omitted") Boolean bestseller,
            @Schema(description = "Up to 4 images; on update, sending any replaces all existing images")
            List<MultipartFile> images) {
    }
}
