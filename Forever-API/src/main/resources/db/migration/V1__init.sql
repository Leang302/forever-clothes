CREATE TABLE users (
    id             BIGSERIAL PRIMARY KEY,
    name           VARCHAR(120) NOT NULL,
    email          VARCHAR(190) NOT NULL UNIQUE,
    password_hash  VARCHAR(100) NOT NULL,
    phone          VARCHAR(40),
    role           VARCHAR(20)  NOT NULL DEFAULT 'USER',
    email_verified BOOLEAN      NOT NULL DEFAULT FALSE,
    enabled        BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE otp_codes (
    id         BIGSERIAL PRIMARY KEY,
    email      VARCHAR(190) NOT NULL,
    purpose    VARCHAR(30)  NOT NULL,
    code_hash  VARCHAR(64)  NOT NULL,
    attempts   INT          NOT NULL DEFAULT 0,
    consumed   BOOLEAN      NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMPTZ  NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_otp_email_purpose ON otp_codes (email, purpose, created_at DESC);

CREATE TABLE refresh_tokens (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    revoked    BOOLEAN     NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_refresh_user ON refresh_tokens (user_id);

CREATE TABLE products (
    id           BIGSERIAL PRIMARY KEY,
    name         VARCHAR(200)   NOT NULL,
    description  TEXT           NOT NULL,
    price        NUMERIC(12, 2) NOT NULL,
    category     VARCHAR(40)    NOT NULL,
    sub_category VARCHAR(40)    NOT NULL,
    bestseller   BOOLEAN        NOT NULL DEFAULT FALSE,
    active       BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ    NOT NULL DEFAULT now()
);
CREATE INDEX idx_products_category ON products (category, sub_category);

CREATE TABLE product_sizes (
    product_id BIGINT      NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    position   INT         NOT NULL,
    size       VARCHAR(20) NOT NULL,
    PRIMARY KEY (product_id, position)
);

CREATE TABLE product_images (
    product_id BIGINT       NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    position   INT          NOT NULL,
    image_key  VARCHAR(300) NOT NULL,
    PRIMARY KEY (product_id, position)
);

CREATE TABLE cart_items (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    product_id BIGINT      NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    size       VARCHAR(20) NOT NULL,
    quantity   INT         NOT NULL CHECK (quantity > 0),
    UNIQUE (user_id, product_id, size)
);

CREATE TABLE orders (
    id             BIGSERIAL PRIMARY KEY,
    user_id        BIGINT         NOT NULL REFERENCES users (id),
    status         VARCHAR(30)    NOT NULL,
    payment_method VARCHAR(20)    NOT NULL,
    paid           BOOLEAN        NOT NULL DEFAULT FALSE,
    items_amount   NUMERIC(12, 2) NOT NULL,
    delivery_fee   NUMERIC(12, 2) NOT NULL,
    total          NUMERIC(12, 2) NOT NULL,
    first_name     VARCHAR(80)    NOT NULL,
    last_name      VARCHAR(80)    NOT NULL,
    email          VARCHAR(190)   NOT NULL,
    street         VARCHAR(200)   NOT NULL,
    city           VARCHAR(100)   NOT NULL,
    state          VARCHAR(100)   NOT NULL,
    zipcode        VARCHAR(20)    NOT NULL,
    country        VARCHAR(100)   NOT NULL,
    phone          VARCHAR(40)    NOT NULL,
    created_at     TIMESTAMPTZ    NOT NULL DEFAULT now()
);
CREATE INDEX idx_orders_user ON orders (user_id, created_at DESC);

CREATE TABLE order_items (
    id         BIGSERIAL PRIMARY KEY,
    order_id   BIGINT         NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    product_id BIGINT         REFERENCES products (id) ON DELETE SET NULL,
    name       VARCHAR(200)   NOT NULL,
    image_key  VARCHAR(300),
    price      NUMERIC(12, 2) NOT NULL,
    size       VARCHAR(20)    NOT NULL,
    quantity   INT            NOT NULL CHECK (quantity > 0)
);
CREATE INDEX idx_order_items_order ON order_items (order_id);
