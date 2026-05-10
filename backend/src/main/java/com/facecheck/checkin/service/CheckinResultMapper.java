package com.facecheck.checkin.service;

import com.facecheck.checkin.api.dto.CheckinAttemptResponse;
import com.facecheck.checkin.config.CheckinProperties;
import com.facecheck.checkin.model.AttendanceCheckinAttempt;
import com.facecheck.checkin.model.AttendanceRecord;
import com.facecheck.checkin.model.CheckinStatus;
import com.facecheck.identity.repo.UserRepository;
import com.facecheck.session.model.AttendanceSession;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
public class CheckinResultMapper {

    private final UserRepository userRepository;
    private final CheckinProperties checkinProperties;

    public CheckinResultMapper(UserRepository userRepository, CheckinProperties checkinProperties) {
        this.userRepository = userRepository;
        this.checkinProperties = checkinProperties;
    }

    public CheckinAttemptResponse toResponse(
            AttendanceCheckinAttempt attempt,
            AttendanceSession session,
            AttendanceRecord record
    ) {
        return new CheckinAttemptResponse(
                attempt.getId(),
                session.getId(),
                session.getName(),
                attempt.getStatus(),
                attempt.getResultCode(),
                resultMessage(attempt),
                record == null ? null : record.getCheckinTime(),
                maskedUsername(attempt.getMatchedUserId()),
                attempt.getSimilarity(),
                attempt.getStatus() == CheckinStatus.PROCESSING ? checkinProperties.getNextPollAfterSeconds() : null
        );
    }

    private String maskedUsername(UUID userId) {
        if (userId == null) {
            return null;
        }
        return userRepository.findById(userId)
                .map(user -> {
                    String username = user.getUsername();
                    if (username == null || username.isBlank()) {
                        return null;
                    }
                    if (username.length() <= 2) {
                        return username.charAt(0) + "*";
                    }
                    return username.charAt(0) + "***" + username.charAt(username.length() - 1);
                })
                .orElse(null);
    }

    private String resultMessage(AttendanceCheckinAttempt attempt) {
        if (attempt.getStatus() == CheckinStatus.PROCESSING) {
            return "The check-in is still being processed.";
        }
        if (attempt.getFailureReason() != null && !attempt.getFailureReason().isBlank()) {
            return attempt.getFailureReason();
        }
        return switch (attempt.getResultCode()) {
            case "SUCCESS" -> "Check-in completed successfully.";
            case "DUPLICATE_CHECKIN" -> "This user has already checked in for the session.";
            case "NO_FACE" -> "No face was detected in the submitted image.";
            case "MULTIPLE_FACES" -> "Multiple faces were detected in the submitted image.";
            case "INVALID_IMAGE" -> "The submitted image is invalid for face recognition.";
            case "LOW_CONFIDENCE" -> "The matched face confidence is below the acceptance threshold.";
            case "NO_MATCH" -> "No enrolled face matched the submitted image.";
            case "FRS_TIMEOUT" -> "The face recognition service timed out.";
            case "FRS_RATE_LIMITED" -> "The face recognition service rate-limited the request.";
            case "FRS_ERROR" -> "The face recognition service returned an unexpected error.";
            case "MANUAL_REVIEW" -> "The recognition result requires manual review.";
            default -> "The check-in request failed.";
        };
    }
}
