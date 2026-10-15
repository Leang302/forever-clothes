-- Order statuses are now ORDER_PLACED -> SHIPPED -> DELIVERED (plus CANCELLED, and PAYMENT_PENDING for online payment).
-- Fold the removed steps into their nearest remaining one.
UPDATE orders SET status = 'ORDER_PLACED' WHERE status = 'PACKING';
UPDATE orders SET status = 'SHIPPED' WHERE status = 'OUT_FOR_DELIVERY';
