package com.forever.foreverapi.common.response;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.Instant;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record ErrorResponse(
        Instant timestamp,
        int status,
        String code,
        String message,
        Map<String, String> fieldErrors,
        String path) {
}
