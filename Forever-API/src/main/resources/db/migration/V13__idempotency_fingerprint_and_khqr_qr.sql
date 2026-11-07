-- A replayed idempotency key must carry the same checkout details; the fingerprint lets the server tell.
ALTER TABLE orders ADD COLUMN idempotency_fingerprint VARCHAR(64);
-- The KHQR the customer was shown, so a retried checkout hands back the same code (and MD5) instead of
-- minting a new one that would orphan a payment already made against the first.
ALTER TABLE orders ADD COLUMN khqr_qr TEXT;
ALTER TABLE orders ADD COLUMN khqr_expires_at TIMESTAMPTZ;
