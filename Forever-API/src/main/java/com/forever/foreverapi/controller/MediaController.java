package com.forever.foreverapi.controller;

import com.forever.foreverapi.client.minio.StorageService;
import com.forever.foreverapi.exception.ApiException;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.servlet.http.HttpServletRequest;
import java.time.Duration;

@RestController
@RequestMapping("/api/media")
@Tag(name = "Media")
public class MediaController {

    private static final String PREFIX = "/api/media/";

    private final StorageService storage;

    public MediaController(StorageService storage) {
        this.storage = storage;
    }

    @Operation(summary = "Stream a stored image by object key, e.g. /api/media/products/p_img1.png")
    @GetMapping("/**")
    public ResponseEntity<InputStreamResource> get(HttpServletRequest request) {
        String uri = request.getRequestURI();
        String key = uri.substring(uri.indexOf(PREFIX) + PREFIX.length());
        if (key.isBlank() || key.contains("..")) {
            throw ApiException.notFound("File not found");
        }
        StorageService.StoredObject obj = storage.get(key);
        MediaType type = obj.contentType() != null ? MediaType.parseMediaType(obj.contentType())
                : MediaType.APPLICATION_OCTET_STREAM;
        return ResponseEntity.ok()
                .contentType(type)
                .contentLength(obj.size())
                .header(HttpHeaders.ETAG, "\"" + obj.etag() + "\"")
                .header("X-Content-Type-Options", "nosniff") // never let a browser treat a stored file as anything else
                .cacheControl(CacheControl.maxAge(Duration.ofDays(7)).cachePublic())
                .body(new InputStreamResource(obj.stream()));
    }
}
