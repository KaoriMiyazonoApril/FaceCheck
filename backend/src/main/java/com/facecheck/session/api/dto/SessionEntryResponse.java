package com.facecheck.session.api.dto;

import com.facecheck.session.model.AttendanceSession;
import com.facecheck.session.model.AttendanceSessionStatus;
import java.time.Instant;
import java.util.UUID;

public record SessionEntryResponse(
        UUID sessionId,
        String name,
        String description,
        Instant startTime,
        Instant endTime,
        AttendanceSessionStatus status,
        boolean canCheckin,
        String refusalCode,
        String refusalReason
) {

    public static SessionEntryResponse available(AttendanceSession session) {
        return new SessionEntryResponse(
                session.getId(),
                session.getName(),
                session.getDescription(),
                session.getStartTime(),
                session.getEndTime(),
                session.getStatus(),
                true,
                null,
                null
        );
    }

    public static SessionEntryResponse refused(AttendanceSession session, String refusalCode, String refusalReason) {
        return new SessionEntryResponse(
                session.getId(),
                session.getName(),
                session.getDescription(),
                session.getStartTime(),
                session.getEndTime(),
                session.getStatus(),
                false,
                refusalCode,
                refusalReason
        );
    }
}
