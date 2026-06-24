package com.facecheck.checkin.service;

import com.facecheck.checkin.model.AttendanceCheckinAttempt;
import com.facecheck.checkin.model.CheckinStatus;
import com.facecheck.checkin.repo.AttendanceCheckinAttemptRepository;
import com.facecheck.common.error.BusinessException;
import com.facecheck.common.error.ErrorCode;
import com.facecheck.face.service.FaceImageValidationService;
import com.facecheck.session.model.AttendanceSession;
import com.facecheck.storage.HuaweiObsStorageService;
import com.facecheck.storage.ObjectKeyStrategy;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class CheckinAttemptService {

    private final AttendanceCheckinAttemptRepository attendanceCheckinAttemptRepository;
    private final FaceImageValidationService faceImageValidationService;
    private final HuaweiObsStorageService storageService;
    private final ObjectKeyStrategy objectKeyStrategy;

    public CheckinAttemptService(
            AttendanceCheckinAttemptRepository attendanceCheckinAttemptRepository,
            FaceImageValidationService faceImageValidationService,
            HuaweiObsStorageService storageService,
            ObjectKeyStrategy objectKeyStrategy
    ) {
        this.attendanceCheckinAttemptRepository = attendanceCheckinAttemptRepository;
        this.faceImageValidationService = faceImageValidationService;
        this.storageService = storageService;
        this.objectKeyStrategy = objectKeyStrategy;
    }

    @Transactional(readOnly = true)
    public Optional<AttendanceCheckinAttempt> findBySessionAndIdempotency(UUID sessionId, String idempotencyKey) {
        return attendanceCheckinAttemptRepository.findBySessionIdAndIdempotencyKey(sessionId, idempotencyKey);
    }

    @Transactional
    public CreatedAttempt createAttempt(
            AttendanceSession session,
            String idempotencyKey,
            String clientIp,
            String deviceId,
            MultipartFile file
    ) {
        Optional<AttendanceCheckinAttempt> existing =
                attendanceCheckinAttemptRepository.findBySessionIdAndIdempotencyKey(session.getId(), idempotencyKey);
        if (existing.isPresent()) {
            return new CreatedAttempt(existing.get(), false);
        }

        FaceImageValidationService.ValidatedImage validatedImage = faceImageValidationService.validate(file);
        UUID attemptId = UUID.randomUUID();
        String objectKey = objectKeyStrategy.checkinAttemptKey(session.getId(), attemptId);
        HuaweiObsStorageService.StoredObject storedObject =
                storageService.upload(objectKey, validatedImage.content(), validatedImage.contentType());

        int inserted = attendanceCheckinAttemptRepository.insertProcessingAttemptIfAbsent(
                attemptId,
                session.getId(),
                storedObject.bucket(),
                storedObject.region(),
                storedObject.objectKey(),
                storedObject.contentType(),
                storedObject.sizeBytes(),
                validatedImage.sha256(),
                storedObject.storageProvider(),
                CheckinStatus.PROCESSING.name(),
                "PROCESSING",
                idempotencyKey,
                clientIp,
                deviceId
        );

        if (inserted == 0) {
            storageService.delete(objectKey);
            return new CreatedAttempt(
                    attendanceCheckinAttemptRepository.findBySessionIdAndIdempotencyKey(session.getId(), idempotencyKey)
                            .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR, "Check-in attempt already exists but cannot be loaded.")),
                    false
            );
        }

        return new CreatedAttempt(attendanceCheckinAttemptRepository.findById(attemptId)
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR, "Check-in attempt was not persisted.")), true);
    }

    @Transactional(readOnly = true)
    public AttendanceCheckinAttempt getAttempt(UUID attemptId) {
        return attendanceCheckinAttemptRepository.findById(attemptId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Check-in attempt does not exist"));
    }

    @Transactional
    public AttendanceCheckinAttempt saveOutcome(
            AttendanceCheckinAttempt attempt,
            CheckinStatus status,
            String resultCode,
            String failureReason,
            UUID matchedUserId,
            String matchedFaceId,
            Double similarity,
            String frsRequestId
    ) {
        attempt.setStatus(status);
        attempt.setResultCode(resultCode);
        attempt.setFailureReason(failureReason);
        attempt.setMatchedUserId(matchedUserId);
        attempt.setMatchedFaceId(matchedFaceId);
        attempt.setSimilarity(similarity);
        attempt.setFrsRequestId(frsRequestId);
        return attendanceCheckinAttemptRepository.save(attempt);
    }

    public record CreatedAttempt(AttendanceCheckinAttempt attempt, boolean createdNow) {
    }
}
