-- Richer coupons: percent or fixed amount, caps, minimum spend, schedule and usage limits.
-- Existing coupons keep working as percent coupons without limits.
ALTER TABLE coupons ALTER COLUMN percent_off DROP NOT NULL;
ALTER TABLE coupons
    ADD COLUMN description        VARCHAR(200),
    ADD COLUMN discount_type      VARCHAR(10)    NOT NULL DEFAULT 'PERCENT',
    ADD COLUMN amount_off         NUMERIC(12, 2),
    ADD COLUMN max_discount       NUMERIC(12, 2),
    ADD COLUMN min_subtotal       NUMERIC(12, 2) NOT NULL DEFAULT 0,
    ADD COLUMN starts_at          TIMESTAMPTZ,
    ADD COLUMN usage_limit        INT,
    ADD COLUMN per_customer_limit INT,
    ADD COLUMN created_at         TIMESTAMPTZ    NOT NULL DEFAULT now();

ALTER TABLE coupons
    ADD CONSTRAINT coupons_discount_type_chk CHECK (discount_type IN ('PERCENT', 'FIXED')),
    ADD CONSTRAINT coupons_value_chk CHECK (
        (discount_type = 'PERCENT' AND percent_off IS NOT NULL)
        OR (discount_type = 'FIXED' AND amount_off IS NOT NULL AND amount_off > 0)),
    ADD CONSTRAINT coupons_limits_chk CHECK (
        (usage_limit IS NULL OR usage_limit > 0)
        AND (per_customer_limit IS NULL OR per_customer_limit > 0)
        AND (max_discount IS NULL OR max_discount > 0)
        AND min_subtotal >= 0);

CREATE INDEX idx_orders_coupon ON orders (upper(coupon_code)) WHERE coupon_code IS NOT NULL;
