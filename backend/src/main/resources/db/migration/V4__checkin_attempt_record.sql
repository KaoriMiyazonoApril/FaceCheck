CREATE TABLE attendance_checkin_attempt (
    id UUID PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES attendance_session (id),
    obs_bucket VARCHAR(128) NOT NULL,
    obs_region VARCHAR(128) NOT NULL,
    obs_object_key VARCHAR(255) NOT NULL,
    content_type VARCHAR(64) NOT NULL,
    size_bytes BIGINT NOT NULL,
    sha256 VARCHAR(64) NOT NULL,
    storage_provider VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL,
    result_code VARCHAR(64) NOT NULL,
    failure_reason VARCHAR(255),
    frs_request_id VARCHAR(128),
    matched_user_id UUID REFERENCES user_account (id),
    matched_face_id VARCHAR(128),
    similarity DOUBLE PRECISION,
    idempotency_key VARCHAR(128) NOT NULL,
    client_ip VARCHAR(64),
    device_id VARCHAR(128),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_attendance_checkin_attempt_session_idempotency UNIQUE (session_id, idempotency_key),
    CONSTRAINT chk_attendance_checkin_attempt_status CHECK (
        status IN ('PROCESSING', 'SUCCESS', 'FAILED', 'DUPLICATE_CHECKIN')
    )
);

CREATE INDEX idx_attendance_checkin_attempt_session_created_at
    ON attendance_checkin_attempt (session_id, created_at DESC);

CREATE INDEX idx_attendance_checkin_attempt_status_created_at
    ON attendance_checkin_attempt (status, created_at DESC);

CREATE INDEX idx_attendance_checkin_attempt_result_code
    ON attendance_checkin_attempt (result_code);

CREATE TABLE attendance_record (
    id UUID PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES attendance_session (id),
    user_id UUID NOT NULL REFERENCES user_account (id),
    attempt_id UUID NOT NULL REFERENCES attendance_checkin_attempt (id),
    checkin_time TIMESTAMPTZ NOT NULL,
    status VARCHAR(32) NOT NULL,
    similarity DOUBLE PRECISION,
    source VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_attendance_record_session_user UNIQUE (session_id, user_id),
    CONSTRAINT uk_attendance_record_attempt UNIQUE (attempt_id),
    CONSTRAINT chk_attendance_record_status CHECK (status IN ('VALID', 'MANUAL_CONFIRMED')),
    CONSTRAINT chk_attendance_record_source CHECK (source IN ('APP_QR_ANON', 'ADMIN_RETRY'))
);

CREATE INDEX idx_attendance_record_session_checkin_time
    ON attendance_record (session_id, checkin_time DESC);

CREATE INDEX idx_attendance_record_user_checkin_time
    ON attendance_record (user_id, checkin_time DESC);
