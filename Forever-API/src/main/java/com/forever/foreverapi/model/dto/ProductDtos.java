package com.forever.foreverapi.model.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import org.springframework.web.multipart.MultipartFile;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;

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
            Instant createdAt,
            @Schema(description = "Units left per size, in the same order as `sizes`") Map<String, Integer> stock,
            @Schema(description = "Active and at least one size has stock left") boolean inStock) {
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
            List<MultipartFile> images,
            @Schema(description = "Image URLs (http/https), an alternative to uploading files; together with "
                    + "`images` at most 4. On update, sending any replaces all existing images")
            List<String> imageUrls,
            @Schema(description = "Visible in the shop. Omitted: true on create, unchanged on update") Boolean active,
            @Schema(description = "Sets every size's stock to this number. Omitted: new sizes start at 20, "
                    + "existing per-size stock is kept") @Min(0) @Max(100000) Integer stock) {
    }
}
