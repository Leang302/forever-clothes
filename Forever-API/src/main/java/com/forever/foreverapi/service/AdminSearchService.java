package com.forever.foreverapi.service;

import com.forever.foreverapi.common.response.PageResponse;
import com.forever.foreverapi.model.dto.OrderDtos.OrderResponse;
import com.forever.foreverapi.model.dto.ProductDtos.ProductResponse;

import java.time.LocalDate;
import java.util.List;

/** Filtered, sorted and paginated lists for the admin panel. */
public interface AdminSearchService {

    /**
     * @param q             order id (with or without #), or part of customer name / email / phone
     * @param paymentMethod COD or PAYWAY
     * @param from          first day (inclusive, UTC)
     * @param to            last day (inclusive, UTC)
     * @param sort          newest | oldest | total_desc | total_asc | status
     */
    PageResponse<OrderResponse> orders(String q, String status, String paymentMethod, Boolean paid,
                                       LocalDate from, LocalDate to, String sort, int page, int size);

    /**
     * @param categories one or more categories (any match)
     * @param active     true = visible only, false = hidden only, null = both
     * @param sort       newest | oldest | name_asc | name_desc | price_asc | price_desc | stock_asc | stock_desc
     */
    PageResponse<ProductResponse> products(String q, List<String> categories, List<String> subCategories, Boolean active,
                                           String sort, int page, int size);
}
