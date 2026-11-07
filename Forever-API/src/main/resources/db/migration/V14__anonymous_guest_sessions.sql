-- Guests shop with an anonymous cart session instead of a throwaway user account.

CREATE TABLE guest_sessions (
    id           BIGSERIAL PRIMARY KEY,
    token_hash   VARCHAR(64) NOT NULL UNIQUE, -- SHA-256 of the opaque token the client holds; never the token itself
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at   TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_guest_sessions_expires ON guest_sessions (expires_at);

-- A cart line belongs to exactly one owner: a registered user or a guest session (deleted with the session).
ALTER TABLE cart_items ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE cart_items ADD COLUMN guest_session_id BIGINT REFERENCES guest_sessions (id) ON DELETE CASCADE;
ALTER TABLE cart_items ADD CONSTRAINT cart_items_one_owner CHECK ((user_id IS NULL) <> (guest_session_id IS NULL));
CREATE UNIQUE INDEX ux_cart_items_guest_line ON cart_items (guest_session_id, product_id, size)
    WHERE guest_session_id IS NOT NULL;

-- Guest orders have no user. They are business records and outlive the session (the link is just cleared).
-- Access to a guest's own order is via a per-order secret derived from guest_access_nonce (see GuestOrderAccess).
ALTER TABLE orders ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE orders ADD COLUMN guest_session_id BIGINT REFERENCES guest_sessions (id) ON DELETE SET NULL;
ALTER TABLE orders ADD COLUMN guest_access_nonce VARCHAR(64);
ALTER TABLE orders ADD COLUMN guest_access_expires_at TIMESTAMPTZ;
CREATE INDEX idx_orders_guest_session ON orders (guest_session_id);

-- Orders placed through the old throwaway GUEST accounts become plain guest orders (kept; nobody can open them
-- as a customer any more — they were never attached to a real account). The GUEST users themselves are removed
-- by the cleanup job.
UPDATE orders SET user_id = NULL WHERE user_id IN (SELECT id FROM users WHERE role = 'GUEST');
