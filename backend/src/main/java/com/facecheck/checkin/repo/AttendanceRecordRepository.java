package com.facecheck.checkin.repo;

import com.facecheck.checkin.model.AttendanceRecord;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AttendanceRecordRepository extends JpaRepository<AttendanceRecord, UUID> {

    Optional<AttendanceRecord> findBySessionIdAndUserId(UUID sessionId, UUID userId);

    Optional<AttendanceRecord> findByAttemptId(UUID attemptId);
}
