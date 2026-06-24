package com.facecheck.checkin.repo;

import com.facecheck.checkin.model.AttendanceCheckinAttempt;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AttendanceCheckinAttemptRepository
        extends JpaRepository<AttendanceCheckinAttempt, UUID>, JpaSpecificationExecutor<AttendanceCheckinAttempt> {

    Optional<AttendanceCheckinAttempt> findBySessionIdAndIdempotencyKey(UUID sessionId, String idempotencyKey);

    @Modifying
    @Query(value = """
            INSERT INTO attendance_checkin_attempt (
                id,
                session_id,
                obs_bucket,
                obs_region,
                obs_object_key,
                content_type,
                size_bytes,
                sha256,
                storage_provider,
                status,
                result_code,
                idempotency_key,
                client_ip,
                device_id
            )
            VALUES (
                :id,
                :sessionId,
                :obsBucket,
                :obsRegion,
                :obsObjectKey,
                :contentType,
                :sizeBytes,
                :sha256,
                :storageProvider,
                :status,
                :resultCode,
                :idempotencyKey,
                :clientIp,
                :deviceId
            )
            ON CONFLICT (session_id, idempotency_key) DO NOTHING
            """, nativeQuery = true)
    int insertProcessingAttemptIfAbsent(
            @Param("id") UUID id,
            @Param("sessionId") UUID sessionId,
            @Param("obsBucket") String obsBucket,
            @Param("obsRegion") String obsRegion,
            @Param("obsObjectKey") String obsObjectKey,
            @Param("contentType") String contentType,
            @Param("sizeBytes") long sizeBytes,
            @Param("sha256") String sha256,
            @Param("storageProvider") String storageProvider,
            @Param("status") String status,
            @Param("resultCode") String resultCode,
            @Param("idempotencyKey") String idempotencyKey,
            @Param("clientIp") String clientIp,
            @Param("deviceId") String deviceId
    );
}
