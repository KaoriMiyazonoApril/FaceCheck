package com.facecheck.common.api;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.time.Instant;
import org.slf4j.MDC;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record ApiResponse<T>(
        boolean success,
        T data,
        ErrorDetail error,
        String traceId,
        Instant timestamp
) {

    public static <T> ApiResponse<T> success(T data) {
        return new ApiResponse<>(true, data, null, currentTraceId(), Instant.now());
    }

    public static <T> ApiResponse<T> failure(String code, String message) {
        return new ApiResponse<>(false, null, new ErrorDetail(code, message), currentTraceId(), Instant.now());
    }

    private static String currentTraceId() {
        return MDC.get("traceId");
    }

    public record ErrorDetail(String code, String message) {
    }
}
