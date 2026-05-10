package com.facecheck.session.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "attendance_session")
public class AttendanceSession {

    @Id
    private UUID id;

    @Column(nullable = false, length = 128)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "start_time", nullable = false)
    private Instant startTime;

    @Column(name = "end_time", nullable = false)
    private Instant endTime;

    @Column(name = "late_after_time")
    private Instant lateAfterTime;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private AttendanceSessionStatus status;

    @Column(name = "qr_token", nullable = false, length = 128, unique = true)
    private String qrToken;

    @Column(name = "qr_token_version", nullable = false)
    private Integer qrTokenVersion;

    @Column(name = "created_by_user_id", nullable = false)
    private UUID createdByUserId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public Instant getStartTime() {
        return startTime;
    }

    public void setStartTime(Instant startTime) {
        this.startTime = startTime;
    }

    public Instant getEndTime() {
        return endTime;
    }

    public void setEndTime(Instant endTime) {
        this.endTime = endTime;
    }

    public Instant getLateAfterTime() {
        return lateAfterTime;
    }

    public void setLateAfterTime(Instant lateAfterTime) {
        this.lateAfterTime = lateAfterTime;
    }

    public AttendanceSessionStatus getStatus() {
        return status;
    }

    public void setStatus(AttendanceSessionStatus status) {
        this.status = status;
    }

    public String getQrToken() {
        return qrToken;
    }

    public void setQrToken(String qrToken) {
        this.qrToken = qrToken;
    }

    public Integer getQrTokenVersion() {
        return qrTokenVersion;
    }

    public void setQrTokenVersion(Integer qrTokenVersion) {
        this.qrTokenVersion = qrTokenVersion;
    }

    public UUID getCreatedByUserId() {
        return createdByUserId;
    }

    public void setCreatedByUserId(UUID createdByUserId) {
        this.createdByUserId = createdByUserId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (status == null) {
            status = AttendanceSessionStatus.DRAFT;
        }
        if (qrTokenVersion == null) {
            qrTokenVersion = 1;
        }
        createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }
}
