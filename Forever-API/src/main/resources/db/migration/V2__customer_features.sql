CREATE TABLE wishlist_items (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, product_id)
);
CREATE INDEX idx_wishlist_user ON wishlist_items (user_id, created_at DESC);

CREATE TABLE saved_addresses (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    label      VARCHAR(50) NOT NULL,
    first_name VARCHAR(80) NOT NULL,
    last_name  VARCHAR(80) NOT NULL,
    email      VARCHAR(190) NOT NULL,
    street     VARCHAR(200) NOT NULL,
    city       VARCHAR(100) NOT NULL,
    state      VARCHAR(100) NOT NULL,
    zipcode    VARCHAR(20) NOT NULL,
    country    VARCHAR(100) NOT NULL,
    phone      VARCHAR(40) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_saved_addresses_user ON saved_addresses (user_id, created_at DESC);
