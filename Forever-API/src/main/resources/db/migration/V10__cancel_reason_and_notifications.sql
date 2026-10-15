-- Why an order was cancelled, and by whom (ADMIN or CUSTOMER).
ALTER TABLE orders ADD COLUMN cancel_reason VARCHAR(500);
ALTER TABLE orders ADD COLUMN cancelled_by VARCHAR(20);

-- Events for the admin panel's notification bell.
CREATE TABLE admin_notifications (
    id         BIGSERIAL PRIMARY KEY,
    type       VARCHAR(30)  NOT NULL,          -- NEW_ORDER, ORDER_CANCELLED, LOW_STOCK, NEW_CUSTOMER
    title      VARCHAR(200) NOT NULL,
    message    VARCHAR(500),
    link       VARCHAR(200),                   -- admin page to open, e.g. /admin/orders?q=%2342
    read_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_admin_notifications_unread ON admin_notifications (created_at DESC) WHERE read_at IS NULL;
