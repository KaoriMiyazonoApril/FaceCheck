package com.facecheck.checkin.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(
        name = "attendance_record",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_attendance_record_session_user", columnNames = {"session_id", "user_id"}),
                @UniqueConstraint(name = "uk_attendance_record_attempt", columnNames = {"attempt_id"})
        }
)
public class AttendanceRecord {

    @Id
    private UUID id;

    @Column(name = "session_id", nullable = false)
    private UUID sessionId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "attempt_id", nullable = false, unique = true)
    private UUID attemptId;

    @Column(name = "checkin_time", nullable = false)
    private Instant checkinTime;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private AttendanceRecordStatus status;

    private Double similarity;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private AttendanceRecordSource source;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public UUID getSessionId() {
        return sessionId;
    }

    public void setSessionId(UUID sessionId) {
        this.sessionId = sessionId;
    }

    public UUID getUserId() {
        return userId;
    }

    public void setUserId(UUID userId) {
        this.userId = userId;
    }

    public UUID getAttemptId() {
        return attemptId;
    }

    public void setAttemptId(UUID attemptId) {
        this.attemptId = attemptId;
    }

    public Instant getCheckinTime() {
        return checkinTime;
    }

    public void setCheckinTime(Instant checkinTime) {
        this.checkinTime = checkinTime;
    }

    public AttendanceRecordStatus getStatus() {
        return status;
    }

    public void setStatus(AttendanceRecordStatus status) {
        this.status = status;
    }

    public Double getSimilarity() {
        return similarity;
    }

    public void setSimilarity(Double similarity) {
        this.similarity = similarity;
    }

    public AttendanceRecordSource getSource() {
        return source;
    }

    public void setSource(AttendanceRecordSource source) {
        this.source = source;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    @PrePersist
    void onCreate() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (status == null) {
            status = AttendanceRecordStatus.VALID;
        }
        if (source == null) {
            source = AttendanceRecordSource.APP_QR_ANON;
        }
        if (checkinTime == null) {
            checkinTime = Instant.now();
        }
        createdAt = Instant.now();
    }
}
