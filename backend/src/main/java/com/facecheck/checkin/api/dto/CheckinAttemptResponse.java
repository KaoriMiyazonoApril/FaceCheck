package com.facecheck.checkin.api.dto;

import com.facecheck.checkin.model.CheckinStatus;
import java.time.Instant;
import java.util.UUID;

public record CheckinAttemptResponse(
        UUID attemptId,
        UUID sessionId,
        String sessionName,
        CheckinStatus status,
        String resultCode,
        String resultMessage,
        Instant checkinTime,
        String maskedUsername,
        Double similarity,
        Integer nextPollAfterSeconds
) {
}
