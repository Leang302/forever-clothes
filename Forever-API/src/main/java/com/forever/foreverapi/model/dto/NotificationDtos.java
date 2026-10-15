package com.forever.foreverapi.model.dto;

import java.time.Instant;
import java.util.List;

public final class NotificationDtos {
    private NotificationDtos() {}

    /** {@code type}: NEW_ORDER, ORDER_CANCELLED, LOW_STOCK or NEW_CUSTOMER. {@code link} is an admin page path. */
    public record NotificationRow(Long id, String type, String title, String message, String link, boolean read,
                                  Instant createdAt) {}

    public record NotificationList(List<NotificationRow> items, long unreadCount) {}
}
