package com.forever.foreverapi.service;

import com.forever.foreverapi.model.dto.CommerceDtos.CouponPreview;
import com.forever.foreverapi.model.dto.CommerceDtos.CouponRequest;
import com.forever.foreverapi.model.dto.CommerceDtos.CouponRow;
import java.math.BigDecimal;
import java.util.List;

public interface CouponService {
    List<CouponRow> list();
    CouponRow create(CouponRequest request);
    CouponRow update(Long id, CouponRequest request);
    CouponRow setActive(Long id, boolean active);
    void delete(Long id);

    /**
     * Discount for {@code subtotal} with {@code code}, or an ApiException (400) explaining why the coupon
     * cannot be used. {@code userId} may be null, in which case the per-customer limit is not checked.
     */
    BigDecimal discountFor(String code, BigDecimal subtotal, Long userId);

    CouponPreview preview(String code, BigDecimal subtotal, Long userId);
}
