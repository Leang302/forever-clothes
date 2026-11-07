package com.forever.foreverapi.util;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

/**
 * Builds absolute image URLs. With `app.public-url` (PUBLIC_API_URL) set — production — they always use that
 * public address, so pages rendered by the SSR server (which calls the API on an internal hostname) and link
 * previews still get reachable images. Unset — local dev — they follow the host the client used, so
 * emulators/devices get a reachable address.
 */
@Component
public class MediaUrls {

    private final String publicUrl;

    public MediaUrls(@Value("${app.public-url:}") String publicUrl) {
        this.publicUrl = publicUrl == null ? "" : publicUrl.trim().replaceAll("/+$", "");
    }

    public String url(String key) {
        if (key.startsWith("https://") || key.startsWith("http://")) return key; // admin-entered image URL
        if (!publicUrl.isEmpty()) return publicUrl + "/api/media/" + key;
        return ServletUriComponentsBuilder.fromCurrentContextPath().path("/api/media/").path(key).build().toUriString();
    }
}
