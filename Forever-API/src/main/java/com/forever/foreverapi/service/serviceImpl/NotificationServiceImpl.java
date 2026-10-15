package com.forever.foreverapi.service.serviceImpl;

import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.model.dto.NotificationDtos.NotificationList;
import com.forever.foreverapi.model.dto.NotificationDtos.NotificationRow;
import com.forever.foreverapi.service.NotificationService;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

@Service
public class NotificationServiceImpl implements NotificationService {
    private final JdbcClient db;

    public NotificationServiceImpl(JdbcClient db) { this.db = db; }

    /** Runs in the caller's transaction, so the notification only exists if the event itself was saved. */
    public void notifyAdmins(String type, String title, String message, String link) {
        db.sql("insert into admin_notifications(type,title,message,link) values(:type,:title,:message,:link)")
                .param("type", type).param("title", truncate(title, 200)).param("message", truncate(message, 500))
                .param("link", link).update();
    }

    public NotificationList list(boolean unreadOnly, int limit) {
        var items = db.sql("select id,type,title,message,link,read_at is not null,created_at from admin_notifications"
                        + (unreadOnly ? " where read_at is null" : "") + " order by created_at desc, id desc limit :limit")
                .param("limit", Math.max(1, Math.min(limit, 100)))
                .query((rs, n) -> new NotificationRow(rs.getLong(1), rs.getString(2), rs.getString(3), rs.getString(4),
                        rs.getString(5), rs.getBoolean(6), rs.getTimestamp(7).toInstant())).list();
        long unread = db.sql("select count(*) from admin_notifications where read_at is null").query(Long.class).single();
        return new NotificationList(items, unread);
    }

    public void markRead(Long id) {
        if (db.sql("update admin_notifications set read_at=coalesce(read_at, now()) where id=:id").param("id", id).update() == 0) {
            throw ApiException.notFound("Notification not found");
        }
    }

    public void markAllRead() {
        db.sql("update admin_notifications set read_at=now() where read_at is null").update();
    }

    private static String truncate(String s, int max) {
        return s == null || s.length() <= max ? s : s.substring(0, max - 1) + "…";
    }
}
