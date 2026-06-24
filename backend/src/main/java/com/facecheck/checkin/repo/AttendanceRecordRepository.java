package com.facecheck.checkin.repo;

import com.facecheck.checkin.model.AttendanceRecord;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AttendanceRecordRepository
        extends JpaRepository<AttendanceRecord, UUID>, JpaSpecificationExecutor<AttendanceRecord> {

    Optional<AttendanceRecord> findBySessionIdAndUserId(UUID sessionId, UUID userId);

    Optional<AttendanceRecord> findByAttemptId(UUID attemptId);

    @Modifying
    @Query(value = """
            INSERT INTO attendance_record (
                id,
                session_id,
                user_id,
                attempt_id,
                checkin_time,
                status,
                similarity,
                source
            )
            VALUES (
                :id,
                :sessionId,
                :userId,
                :attemptId,
                :checkinTime,
                :status,
                :similarity,
                :source
            )
            ON CONFLICT DO NOTHING
            """, nativeQuery = true)
    int insertRecordIfAbsent(
            @Param("id") UUID id,
            @Param("sessionId") UUID sessionId,
            @Param("userId") UUID userId,
            @Param("attemptId") UUID attemptId,
            @Param("checkinTime") Instant checkinTime,
            @Param("status") String status,
            @Param("similarity") Double similarity,
            @Param("source") String source
    );
}
