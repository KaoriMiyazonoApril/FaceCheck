CREATE TABLE attendance_session (
    id UUID PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    description TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    late_after_time TIMESTAMPTZ,
    status VARCHAR(16) NOT NULL,
    qr_token VARCHAR(128) NOT NULL,
    qr_token_version INTEGER NOT NULL DEFAULT 1,
    created_by_user_id UUID NOT NULL REFERENCES user_account (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_attendance_session_qr_token UNIQUE (qr_token),
    CONSTRAINT chk_attendance_session_status CHECK (status IN ('DRAFT', 'PUBLISHED', 'CLOSED', 'CANCELED')),
    CONSTRAINT chk_attendance_session_time_window CHECK (start_time < end_time),
    CONSTRAINT chk_attendance_session_late_after_time CHECK (
        late_after_time IS NULL OR (late_after_time >= start_time AND late_after_time <= end_time)
    )
);

CREATE INDEX idx_attendance_session_status_start_time
    ON attendance_session (status, start_time DESC);

CREATE INDEX idx_attendance_session_created_by_created_at
    ON attendance_session (created_by_user_id, created_at DESC);
