package com.forever.foreverapi.model.entity;

public enum PaymentMethod {
    COD, PAYWAY;

    /** Paid up front by scanning a QR, so the order waits in PAYMENT_PENDING until confirmed. */
    public boolean isOnline() { return this != COD; }
}
