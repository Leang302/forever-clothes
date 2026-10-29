-- Bakong KHQR: the MD5 of the QR shown to the customer, used to look the payment up in the Bakong Open API.
ALTER TABLE orders ADD COLUMN khqr_md5 VARCHAR(32);

-- ABA PayWay was removed in favour of KHQR (both are bank QR payments); keep old orders loadable.
UPDATE orders SET payment_method = 'KHQR' WHERE payment_method = 'PAYWAY';
