package com.facecheck.checkin.messaging;

import java.util.UUID;

public record CheckinProcessTask(UUID attemptId, UUID sessionId, int retryCount) {
}
