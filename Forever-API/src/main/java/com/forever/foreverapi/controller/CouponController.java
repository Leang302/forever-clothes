package com.forever.foreverapi.controller;

import com.forever.foreverapi.common.security.AuthUser;
import com.forever.foreverapi.model.dto.CommerceDtos.CouponCheckRequest;
import com.forever.foreverapi.model.dto.CommerceDtos.CouponPreview;
import com.forever.foreverapi.model.dto.CommerceDtos.CouponRequest;
import com.forever.foreverapi.model.dto.CommerceDtos.CouponRow;
import com.forever.foreverapi.service.CouponService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@Tag(name = "Coupons", description = "Admin coupon management (ADMIN role) and checkout coupon preview")
public class CouponController {

    private final CouponService coupons;

    public CouponController(CouponService coupons) {
        this.coupons = coupons;
    }

    @Operation(summary = "Check a coupon for the current customer and preview the discount for a subtotal")
    @PostMapping("/api/checkout/coupon")
    public CouponPreview check(@AuthenticationPrincipal AuthUser user, @Valid @RequestBody CouponCheckRequest req) {
        return coupons.preview(req.code(), req.subtotal(), user == null ? null : user.id());
    }

    @Operation(summary = "All coupons with status and usage")
    @GetMapping("/api/admin/coupons")
    public List<CouponRow> list() {
        return coupons.list();
    }

    @PostMapping("/api/admin/coupons")
    @ResponseStatus(HttpStatus.CREATED)
    public CouponRow create(@Valid @RequestBody CouponRequest request) {
        return coupons.create(request);
    }

    @PutMapping("/api/admin/coupons/{id}")
    public CouponRow update(@PathVariable Long id, @Valid @RequestBody CouponRequest request) {
        return coupons.update(id, request);
    }

    @PatchMapping("/api/admin/coupons/{id}/active")
    public CouponRow setActive(@PathVariable Long id, @RequestParam boolean active) {
        return coupons.setActive(id, active);
    }

    @DeleteMapping("/api/admin/coupons/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        coupons.delete(id);
    }
}
