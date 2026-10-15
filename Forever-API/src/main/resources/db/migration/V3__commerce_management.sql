CREATE TABLE product_inventory (
    product_id BIGINT NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    size VARCHAR(20) NOT NULL,
    stock INT NOT NULL DEFAULT 20 CHECK (stock >= 0),
    PRIMARY KEY (product_id, size)
);
INSERT INTO product_inventory (product_id, size, stock)
SELECT product_id, size, 20 FROM product_sizes ON CONFLICT DO NOTHING;

CREATE TABLE categories (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(40) NOT NULL UNIQUE,
    active BOOLEAN NOT NULL DEFAULT TRUE
);
INSERT INTO categories (name)
SELECT DISTINCT category FROM products ON CONFLICT DO NOTHING;

CREATE TABLE coupons (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    percent_off INT NOT NULL CHECK (percent_off BETWEEN 1 AND 90),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    expires_at TIMESTAMPTZ
);

ALTER TABLE orders ADD COLUMN discount NUMERIC(12, 2) NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN coupon_code VARCHAR(30);
ALTER TABLE orders ADD COLUMN shipping_method VARCHAR(20) NOT NULL DEFAULT 'STANDARD';
