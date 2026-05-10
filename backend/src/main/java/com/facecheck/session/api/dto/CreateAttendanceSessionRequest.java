package com.facecheck.session.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;

public record CreateAttendanceSessionRequest(
        @NotBlank @Size(max = 128) String name,
        @Size(max = 2000) String description,
        @NotNull Instant startTime,
        @NotNull Instant endTime,
        Instant lateAfterTime
) {
}
