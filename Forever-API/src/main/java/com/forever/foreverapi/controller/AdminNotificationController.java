package com.forever.foreverapi.controller;

import com.forever.foreverapi.model.dto.NotificationDtos.NotificationList;
import com.forever.foreverapi.service.NotificationService;
import io.swagger.v3.oas.annotations.Operation;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/admin/notifications")
public class AdminNotificationController {
    private final NotificationService notifications;

    public AdminNotificationController(NotificationService notifications) { this.notifications = notifications; }

    @Operation(summary = "Admin notifications, newest first, with the unread count")
    @GetMapping
    public NotificationList list(@RequestParam(defaultValue = "false") boolean unreadOnly,
                                 @RequestParam(defaultValue = "20") int limit) {
        return notifications.list(unreadOnly, limit);
    }

    @PostMapping("/{id}/read") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markRead(@PathVariable Long id) { notifications.markRead(id); }

    @PostMapping("/read-all") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markAllRead() { notifications.markAllRead(); }
}
