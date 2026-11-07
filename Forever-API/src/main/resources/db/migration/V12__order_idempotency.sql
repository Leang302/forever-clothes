-- Lets the client attach a per-submission key to /api/orders and /api/khqr/checkout so a retried or
-- double-tapped "place order" request returns the already-created order instead of making a second one.
ALTER TABLE orders ADD COLUMN idempotency_key VARCHAR(64);
CREATE UNIQUE INDEX ux_orders_idempotency_key ON orders (idempotency_key) WHERE idempotency_key IS NOT NULL;
