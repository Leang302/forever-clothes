package com.forever.foreverapi.service;

import com.forever.foreverapi.common.response.PageResponse;
import com.forever.foreverapi.model.dto.ProductDtos.FilterOptions;
import com.forever.foreverapi.model.dto.ProductDtos.ProductForm;
import com.forever.foreverapi.model.dto.ProductDtos.ProductResponse;

import java.util.List;

public interface ProductService {
    PageResponse<ProductResponse> search(String q, List<String> categories, List<String> subCategories,
                                         String sort, int page, int size, boolean includeInactive);
    ProductResponse get(Long id);
    ProductResponse getForAdmin(Long id);
    List<ProductResponse> latest(int limit);
    List<ProductResponse> bestsellers(int limit);
    List<ProductResponse> related(Long id, int limit);
    FilterOptions filters();
    ProductResponse create(ProductForm form);
    ProductResponse update(Long id, ProductForm form);
    ProductResponse setActive(Long id, boolean active);
    void delete(Long id);
}
