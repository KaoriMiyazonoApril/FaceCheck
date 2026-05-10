package com.facecheck.checkin.repo;

import com.facecheck.checkin.model.AttendanceCheckinAttempt;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AttendanceCheckinAttemptRepository extends JpaRepository<AttendanceCheckinAttempt, UUID> {

    Optional<AttendanceCheckinAttempt> findBySessionIdAndIdempotencyKey(UUID sessionId, String idempotencyKey);
}
