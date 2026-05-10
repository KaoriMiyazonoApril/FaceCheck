package com.facecheck.session.api.dto;

import com.facecheck.session.model.AttendanceSession;
import com.facecheck.session.model.AttendanceSessionStatus;
import java.time.Instant;
import java.util.UUID;

public record AttendanceSessionSummaryResponse(
        UUID sessionId,
        String name,
        String description,
        Instant startTime,
        Instant endTime,
        Instant lateAfterTime,
        AttendanceSessionStatus status,
        Integer qrTokenVersion,
        Instant createdAt
) {

    public static AttendanceSessionSummaryResponse from(AttendanceSession session) {
        return new AttendanceSessionSummaryResponse(
                session.getId(),
                session.getName(),
                session.getDescription(),
                session.getStartTime(),
                session.getEndTime(),
                session.getLateAfterTime(),
                session.getStatus(),
                session.getQrTokenVersion(),
                session.getCreatedAt()
        );
    }
}
