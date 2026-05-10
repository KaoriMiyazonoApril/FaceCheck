package com.facecheck.session.repo;

import com.facecheck.session.model.AttendanceSession;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AttendanceSessionRepository extends JpaRepository<AttendanceSession, UUID> {

    List<AttendanceSession> findAllByOrderByStartTimeDescCreatedAtDesc();

    Optional<AttendanceSession> findByQrToken(String qrToken);

    boolean existsByQrToken(String qrToken);
}
