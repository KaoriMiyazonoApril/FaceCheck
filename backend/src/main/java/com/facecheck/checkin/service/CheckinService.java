package com.facecheck.checkin.service;

import com.facecheck.checkin.api.dto.CheckinAttemptResponse;
import com.facecheck.checkin.model.AttendanceCheckinAttempt;
import com.facecheck.checkin.model.AttendanceRecord;
import com.facecheck.checkin.model.CheckinStatus;
import com.facecheck.common.error.BusinessException;
import com.facecheck.common.error.ErrorCode;
import com.facecheck.session.model.AttendanceSession;
import com.facecheck.session.model.AttendanceSessionStatus;
import com.facecheck.session.repo.AttendanceSessionRepository;
import com.facecheck.session.service.QrTokenService;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class CheckinService {

    private final QrTokenService qrTokenService;
    private final AttendanceSessionRepository attendanceSessionRepository;
    private final CheckinRateLimitService checkinRateLimitService;
    private final CheckinIdempotencyService checkinIdempotencyService;
    private final CheckinAttemptService checkinAttemptService;
    private final CheckinRecognitionService checkinRecognitionService;
    private final AttendanceRecordService attendanceRecordService;
    private final CheckinResultMapper checkinResultMapper;
    private final CheckinAsyncPolicy checkinAsyncPolicy;

    public CheckinService(
            QrTokenService qrTokenService,
            AttendanceSessionRepository attendanceSessionRepository,
            CheckinRateLimitService checkinRateLimitService,
            CheckinIdempotencyService checkinIdempotencyService,
            CheckinAttemptService checkinAttemptService,
            CheckinRecognitionService checkinRecognitionService,
            AttendanceRecordService attendanceRecordService,
            CheckinResultMapper checkinResultMapper,
            CheckinAsyncPolicy checkinAsyncPolicy
    ) {
        this.qrTokenService = qrTokenService;
        this.attendanceSessionRepository = attendanceSessionRepository;
        this.checkinRateLimitService = checkinRateLimitService;
        this.checkinIdempotencyService = checkinIdempotencyService;
        this.checkinAttemptService = checkinAttemptService;
        this.checkinRecognitionService = checkinRecognitionService;
        this.attendanceRecordService = attendanceRecordService;
        this.checkinResultMapper = checkinResultMapper;
        this.checkinAsyncPolicy = checkinAsyncPolicy;
    }

    @Transactional
    public CheckinAttemptResponse submit(
            String qrToken,
            String idempotencyKey,
            String deviceId,
            String clientIp,
            MultipartFile file
    ) {
        Optional<CheckinAttemptResponse> cachedResponse = checkinIdempotencyService.find(qrToken, idempotencyKey);
        if (cachedResponse.isPresent()) {
            return cachedResponse.get();
        }

        AttendanceSession session = requireAvailableSession(qrToken);

        Optional<AttendanceCheckinAttempt> existingAttempt =
                checkinAttemptService.findBySessionAndIdempotency(session.getId(), idempotencyKey);
        if (existingAttempt.isPresent()) {
            return cacheAndReturn(session, qrToken, idempotencyKey, existingAttempt.get());
        }

        checkinRateLimitService.checkAllowed(session.getId(), clientIp, deviceId);

        CheckinAttemptService.CreatedAttempt createdAttempt =
                checkinAttemptService.createAttempt(session, idempotencyKey, clientIp, deviceId, file);
        if (!createdAttempt.createdNow()) {
            return cacheAndReturn(session, qrToken, idempotencyKey, createdAttempt.attempt());
        }

        AttendanceCheckinAttempt attempt = createdAttempt.attempt();

        if (checkinAsyncPolicy.shouldProcessAsync(session)) {
            CheckinAttemptResponse processingResponse = checkinResultMapper.toResponse(attempt, session, null);
            checkinIdempotencyService.store(qrToken, idempotencyKey, processingResponse, session.getEndTime());
            return processingResponse;
        }

        CheckinRecognitionService.RecognitionOutcome recognitionOutcome = checkinRecognitionService.recognize(attempt);
        AttendanceRecord record = null;

        if (recognitionOutcome.matched()) {
            AttendanceRecordService.RecordOutcome recordOutcome = attendanceRecordService.persist(
                    session.getId(),
                    recognitionOutcome.matchedUserId(),
                    attempt.getId(),
                    recognitionOutcome.similarity()
            );
            record = recordOutcome.record();

            if (recordOutcome.created()) {
                attempt = checkinAttemptService.saveOutcome(
                        attempt,
                        CheckinStatus.SUCCESS,
                        "SUCCESS",
                        null,
                        recognitionOutcome.matchedUserId(),
                        recognitionOutcome.matchedFaceId(),
                        recognitionOutcome.similarity(),
                        recognitionOutcome.frsRequestId()
                );
            } else {
                attempt = checkinAttemptService.saveOutcome(
                        attempt,
                        CheckinStatus.DUPLICATE_CHECKIN,
                        "DUPLICATE_CHECKIN",
                        "This user has already checked in for the session.",
                        recognitionOutcome.matchedUserId(),
                        recognitionOutcome.matchedFaceId(),
                        recognitionOutcome.similarity(),
                        recognitionOutcome.frsRequestId()
                );
            }
        } else {
            attempt = checkinAttemptService.saveOutcome(
                    attempt,
                    CheckinStatus.FAILED,
                    recognitionOutcome.resultCode(),
                    recognitionOutcome.resultMessage(),
                    null,
                    null,
                    null,
                    recognitionOutcome.frsRequestId()
            );
        }

        CheckinAttemptResponse response = checkinResultMapper.toResponse(attempt, session, recordFor(attempt, record));
        checkinIdempotencyService.store(qrToken, idempotencyKey, response, session.getEndTime());
        return response;
    }

    @Transactional(readOnly = true)
    public CheckinAttemptResponse getAttempt(String qrToken, UUID attemptId) {
        AttendanceSession tokenSession = qrTokenService.requireByToken(qrToken);
        AttendanceCheckinAttempt attempt = checkinAttemptService.getAttempt(attemptId);
        if (!tokenSession.getId().equals(attempt.getSessionId())) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "Check-in attempt does not exist");
        }
        AttendanceSession session = attendanceSessionRepository.findById(attempt.getSessionId())
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Attendance session does not exist"));
        return checkinResultMapper.toResponse(attempt, session, recordFor(attempt, null));
    }

    private CheckinAttemptResponse cacheAndReturn(
            AttendanceSession session,
            String qrToken,
            String idempotencyKey,
            AttendanceCheckinAttempt attempt
    ) {
        CheckinAttemptResponse response = checkinResultMapper.toResponse(attempt, session, recordFor(attempt, null));
        if (attempt.getStatus() != CheckinStatus.PROCESSING) {
            checkinIdempotencyService.store(qrToken, idempotencyKey, response, session.getEndTime());
        }
        return response;
    }

    private AttendanceRecord recordFor(AttendanceCheckinAttempt attempt, AttendanceRecord currentRecord) {
        if (currentRecord != null) {
            return currentRecord;
        }
        if (attempt.getStatus() == CheckinStatus.SUCCESS) {
            return attendanceRecordService.findByAttemptId(attempt.getId()).orElse(null);
        }
        if (attempt.getStatus() == CheckinStatus.DUPLICATE_CHECKIN && attempt.getMatchedUserId() != null) {
            return attendanceRecordService.findBySessionAndUser(attempt.getSessionId(), attempt.getMatchedUserId())
                    .orElse(null);
        }
        return null;
    }

    private AttendanceSession requireAvailableSession(String qrToken) {
        AttendanceSession session = qrTokenService.requireByToken(qrToken);
        Instant now = Instant.now();

        if (session.getStatus() == AttendanceSessionStatus.DRAFT) {
            throw new BusinessException(ErrorCode.SESSION_NOT_PUBLISHED, "The session has not been published yet.");
        }
        if (session.getStatus() == AttendanceSessionStatus.CLOSED) {
            throw new BusinessException(ErrorCode.SESSION_CLOSED, "The session has already been closed.");
        }
        if (session.getStatus() == AttendanceSessionStatus.CANCELED) {
            throw new BusinessException(ErrorCode.SESSION_CANCELED, "The session has been canceled.");
        }
        if (now.isBefore(session.getStartTime())) {
            throw new BusinessException(ErrorCode.SESSION_NOT_STARTED, "The session has not started yet.");
        }
        if (now.isAfter(session.getEndTime())) {
            throw new BusinessException(ErrorCode.EXPIRED_SESSION, "The session has already ended.");
        }
        return session;
    }
}
