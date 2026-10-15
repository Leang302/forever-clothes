package com.forever.foreverapi.util;

import org.springframework.stereotype.Component;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

/** Builds image URLs relative to the host the client used, so emulators/devices get a reachable address. */
@Component
public class MediaUrls {

    public String url(String key) {
        return ServletUriComponentsBuilder.fromCurrentContextPath().path("/api/media/").path(key).build().toUriString();
    }
}
