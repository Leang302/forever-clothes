package com.forever.foreverapi.service.serviceImpl;

import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.model.dto.CommerceDtos.CouponPreview;
import com.forever.foreverapi.model.dto.CommerceDtos.CouponRequest;
import com.forever.foreverapi.model.dto.CommerceDtos.CouponRow;
import com.forever.foreverapi.service.CouponService;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;

@Service
public class CouponServiceImpl implements CouponService {

    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("d MMM yyyy", Locale.ENGLISH).withZone(ZoneOffset.UTC);

    /** Coupon columns plus usage (non-cancelled orders) aggregated per code. */
    private static final String SELECT = """
            select c.id, c.code, c.description, c.discount_type, c.percent_off, c.amount_off, c.max_discount,
                   c.min_subtotal, c.starts_at, c.expires_at, c.usage_limit, c.per_customer_limit, c.active, c.created_at,
                   coalesce(u.used, 0) as times_used, coalesce(u.total, 0) as total_discount
            from coupons c
            left join (select upper(coupon_code) as code, count(*) as used, sum(discount) as total
                       from orders where coupon_code is not null and status <> 'CANCELLED'
                       group by upper(coupon_code)) u on u.code = upper(c.code)
            """;

    private final JdbcClient db;

    public CouponServiceImpl(JdbcClient db) {
        this.db = db;
    }

    // ---- admin ----

    @Transactional(readOnly = true)
    public List<CouponRow> list() {
        return db.sql(SELECT + " order by c.id desc").query(this::row).list();
    }

    @Transactional
    public CouponRow create(CouponRequest r) {
        validate(r);
        try {
            Long id = db.sql("""
                    insert into coupons(code, description, discount_type, percent_off, amount_off, max_discount, min_subtotal,
                                        starts_at, expires_at, usage_limit, per_customer_limit, active)
                    values (:code, :description, :type, :percent, :amount, :max, :min, :starts, :expires, :usage, :perCustomer, :active)
                    returning id""")
                    .params(params(r)).query(Long.class).single();
            return get(id);
        } catch (DuplicateKeyException e) {
            throw ApiException.conflict("COUPON_EXISTS", "Coupon code already exists");
        }
    }

    @Transactional
    public CouponRow update(Long id, CouponRequest r) {
        validate(r);
        try {
            var params = params(r);
            params.put("id", id);
            int changed = db.sql("""
                    update coupons set code=:code, description=:description, discount_type=:type, percent_off=:percent,
                           amount_off=:amount, max_discount=:max, min_subtotal=:min, starts_at=:starts, expires_at=:expires,
                           usage_limit=:usage, per_customer_limit=:perCustomer, active=:active
                    where id=:id""").params(params).update();
            if (changed == 0) throw ApiException.notFound("Coupon not found");
            return get(id);
        } catch (DuplicateKeyException e) {
            throw ApiException.conflict("COUPON_EXISTS", "Coupon code already exists");
        }
    }

    @Transactional
    public CouponRow setActive(Long id, boolean active) {
        if (db.sql("update coupons set active=:active where id=:id").param("active", active).param("id", id).update() == 0) {
            throw ApiException.notFound("Coupon not found");
        }
        return get(id);
    }

    @Transactional
    public void delete(Long id) {
        db.sql("delete from coupons where id=:id").param("id", id).update();
    }

    // ---- checkout ----

    @Transactional(readOnly = true)
    public BigDecimal discountFor(String rawCode, BigDecimal subtotal, Long userId) {
        String code = rawCode.trim().toUpperCase(Locale.ROOT);
        CouponRow c = db.sql(SELECT + " where upper(c.code) = :code").param("code", code).query(this::row).optional()
                .orElseThrow(() -> invalid("COUPON_INVALID", "Coupon code \"" + code + "\" does not exist"));

        switch (c.status()) {
            case "INACTIVE" -> throw invalid("COUPON_INACTIVE", "This coupon is no longer active");
            case "SCHEDULED" -> throw invalid("COUPON_NOT_STARTED", "This coupon can be used from " + DATE.format(c.startsAt()));
            case "EXPIRED" -> throw invalid("COUPON_EXPIRED", "This coupon expired on " + DATE.format(c.expiresAt()));
            case "USED_UP" -> throw invalid("COUPON_USED_UP", "This coupon has reached its usage limit");
            default -> { }
        }
        if (subtotal.compareTo(c.minSubtotal()) < 0) {
            throw invalid("COUPON_MIN_SUBTOTAL", "Spend at least $" + money(c.minSubtotal()) + " to use this coupon (you need $"
                    + money(c.minSubtotal().subtract(subtotal)) + " more)");
        }
        if (userId != null && c.perCustomerLimit() != null) {
            long usedByCustomer = db.sql("select count(*) from orders where user_id=:user and upper(coupon_code)=:code and status <> 'CANCELLED'")
                    .param("user", userId).param("code", code).query(Long.class).single();
            if (usedByCustomer >= c.perCustomerLimit()) {
                throw invalid("COUPON_CUSTOMER_LIMIT", c.perCustomerLimit() == 1
                        ? "You have already used this coupon"
                        : "You have already used this coupon " + c.perCustomerLimit() + " times");
            }
        }
        return discount(c, subtotal);
    }

    @Transactional(readOnly = true)
    public CouponPreview preview(String rawCode, BigDecimal subtotal, Long userId) {
        BigDecimal discount = discountFor(rawCode, subtotal, userId);
        CouponRow c = get(db.sql("select id from coupons where upper(code)=:code")
                .param("code", rawCode.trim().toUpperCase(Locale.ROOT)).query(Long.class).single());
        return new CouponPreview(c.code(), c.description(), c.discountType(), discount, summary(c));
    }

    // ---- helpers ----

    private static BigDecimal discount(CouponRow c, BigDecimal subtotal) {
        BigDecimal d;
        if ("FIXED".equals(c.discountType())) {
            d = c.amountOff();
        } else {
            d = subtotal.multiply(BigDecimal.valueOf(c.percentOff())).divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
            if (c.maxDiscount() != null && d.compareTo(c.maxDiscount()) > 0) d = c.maxDiscount();
        }
        return d.min(subtotal).setScale(2, RoundingMode.HALF_UP);
    }

    private static String summary(CouponRow c) {
        String s = "FIXED".equals(c.discountType()) ? "$" + money(c.amountOff()) + " off" : c.percentOff() + "% off";
        if (c.maxDiscount() != null && !"FIXED".equals(c.discountType())) s += " (up to $" + money(c.maxDiscount()) + ")";
        if (c.minSubtotal().signum() > 0) s += " on orders over $" + money(c.minSubtotal());
        return s;
    }

    private static void validate(CouponRequest r) {
        String type = r.discountType() == null ? "PERCENT" : r.discountType();
        if ("PERCENT".equals(type) && r.percentOff() == null) {
            throw ApiException.badRequest("VALIDATION_FAILED", "Percent off is required for a percentage coupon");
        }
        if ("FIXED".equals(type) && r.amountOff() == null) {
            throw ApiException.badRequest("VALIDATION_FAILED", "Amount off is required for a fixed-amount coupon");
        }
        if (r.startsAt() != null && r.expiresAt() != null && !r.expiresAt().isAfter(r.startsAt())) {
            throw ApiException.badRequest("VALIDATION_FAILED", "Expiry date must be after the start date");
        }
        if (r.usageLimit() != null && r.perCustomerLimit() != null && r.perCustomerLimit() > r.usageLimit()) {
            throw ApiException.badRequest("VALIDATION_FAILED", "Per-customer limit cannot be higher than the total usage limit");
        }
    }

    private static java.util.Map<String, Object> params(CouponRequest r) {
        boolean fixed = "FIXED".equals(r.discountType());
        var m = new java.util.HashMap<String, Object>();
        m.put("code", r.code().trim().toUpperCase(Locale.ROOT));
        m.put("description", r.description() == null || r.description().isBlank() ? null : r.description().trim());
        m.put("type", fixed ? "FIXED" : "PERCENT");
        m.put("percent", fixed ? null : r.percentOff());
        m.put("amount", fixed ? r.amountOff() : null);
        m.put("max", fixed ? null : r.maxDiscount());
        m.put("min", r.minSubtotal() == null ? BigDecimal.ZERO : r.minSubtotal());
        m.put("starts", r.startsAt() == null ? null : Timestamp.from(r.startsAt()));
        m.put("expires", r.expiresAt() == null ? null : Timestamp.from(r.expiresAt()));
        m.put("usage", r.usageLimit());
        m.put("perCustomer", r.perCustomerLimit());
        m.put("active", r.active() == null || r.active());
        return m;
    }

    private CouponRow get(Long id) {
        return db.sql(SELECT + " where c.id = :id").param("id", id).query(this::row).optional()
                .orElseThrow(() -> ApiException.notFound("Coupon not found"));
    }

    private CouponRow row(ResultSet rs, int n) throws SQLException {
        Instant starts = instant(rs, "starts_at");
        Instant expires = instant(rs, "expires_at");
        Integer usageLimit = (Integer) rs.getObject("usage_limit");
        long used = rs.getLong("times_used");
        boolean active = rs.getBoolean("active");
        Instant now = Instant.now();
        String status = !active ? "INACTIVE"
                : starts != null && starts.isAfter(now) ? "SCHEDULED"
                : expires != null && !expires.isAfter(now) ? "EXPIRED"
                : usageLimit != null && used >= usageLimit ? "USED_UP"
                : "ACTIVE";
        return new CouponRow(rs.getLong("id"), rs.getString("code"), rs.getString("description"), rs.getString("discount_type"),
                (Integer) rs.getObject("percent_off"), rs.getBigDecimal("amount_off"), rs.getBigDecimal("max_discount"),
                rs.getBigDecimal("min_subtotal"), starts, expires, usageLimit, (Integer) rs.getObject("per_customer_limit"),
                active, used, rs.getBigDecimal("total_discount"), status, instant(rs, "created_at"));
    }

    private static Instant instant(ResultSet rs, String column) throws SQLException {
        Timestamp t = rs.getTimestamp(column);
        return t == null ? null : t.toInstant();
    }

    private static String money(BigDecimal v) {
        return v.setScale(2, RoundingMode.HALF_UP).toPlainString();
    }

    private static ApiException invalid(String code, String message) {
        return ApiException.badRequest(code, message);
    }
}
