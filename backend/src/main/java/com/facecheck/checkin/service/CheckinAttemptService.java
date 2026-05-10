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
import org.springframework.dao.DataIntegrityViolationException;
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

        AttendanceCheckinAttempt attempt = new AttendanceCheckinAttempt();
        attempt.setId(attemptId);
        attempt.setSessionId(session.getId());
        attempt.setObsBucket(storedObject.bucket());
        attempt.setObsRegion(storedObject.region());
        attempt.setObsObjectKey(storedObject.objectKey());
        attempt.setContentType(storedObject.contentType());
        attempt.setSizeBytes(storedObject.sizeBytes());
        attempt.setSha256(validatedImage.sha256());
        attempt.setStorageProvider(storedObject.storageProvider());
        attempt.setStatus(CheckinStatus.PROCESSING);
        attempt.setResultCode("PROCESSING");
        attempt.setIdempotencyKey(idempotencyKey);
        attempt.setClientIp(clientIp);
        attempt.setDeviceId(deviceId);

        try {
            return new CreatedAttempt(attendanceCheckinAttemptRepository.saveAndFlush(attempt), true);
        } catch (DataIntegrityViolationException exception) {
            storageService.delete(objectKey);
            return new CreatedAttempt(
                    attendanceCheckinAttemptRepository.findBySessionIdAndIdempotencyKey(session.getId(), idempotencyKey)
                            .orElseThrow(() -> exception),
                    false
            );
        }
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
