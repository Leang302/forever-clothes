package com.forever.foreverapi.service;

import com.forever.foreverapi.model.dto.NotificationDtos.NotificationList;

/** Events shown in the admin panel's notification bell. */
public interface NotificationService {
    String NEW_ORDER = "NEW_ORDER";
    String ORDER_CANCELLED = "ORDER_CANCELLED";
    String LOW_STOCK = "LOW_STOCK";
    String NEW_CUSTOMER = "NEW_CUSTOMER";

    void notifyAdmins(String type, String title, String message, String link);

    /** Newest first; {@code unreadOnly} limits the list to unread ones. The unread count is always the total. */
    NotificationList list(boolean unreadOnly, int limit);

    void markRead(Long id);

    void markAllRead();
}
