package com.forever.foreverapi.model.entity;

public enum Role {
    USER, ADMIN,
    /** A throwaway account created for guest checkout; excluded from the admin customer list/counts. */
    GUEST
}
