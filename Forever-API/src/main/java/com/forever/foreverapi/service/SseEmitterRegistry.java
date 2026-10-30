package com.forever.foreverapi.service;

import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/** Keeps track of open SSE connections keyed by orderId and broadcasts payment events. */
@Component
public class SseEmitterRegistry {

    private final ConcurrentHashMap<Long, CopyOnWriteArrayList<SseEmitter>> emitters = new ConcurrentHashMap<>();

    /** Register a new SSE connection for the given order. */
    public SseEmitter register(Long orderId) {
        SseEmitter emitter = new SseEmitter(0L); // no server-side timeout; client reconnects if needed
        emitters.computeIfAbsent(orderId, k -> new CopyOnWriteArrayList<>()).add(emitter);
        Runnable cleanup = () -> remove(orderId, emitter);
        emitter.onCompletion(cleanup);
        emitter.onTimeout(cleanup);
        emitter.onError(e -> cleanup.run());
        return emitter;
    }

    /** Push a "paid" event to all listeners for this order then close their connections. */
    public void notifyPaid(Long orderId) {
        List<SseEmitter> list = emitters.remove(orderId);
        if (list == null) return;
        for (SseEmitter emitter : list) {
            try {
                emitter.send(SseEmitter.event().name("paid").data("true"));
                emitter.complete();
            } catch (Exception ignored) {
                emitter.completeWithError(ignored);
            }
        }
    }

    private void remove(Long orderId, SseEmitter emitter) {
        CopyOnWriteArrayList<SseEmitter> list = emitters.get(orderId);
        if (list != null) list.remove(emitter);
    }
}
