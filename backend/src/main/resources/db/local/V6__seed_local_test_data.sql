DO $$
BEGIN
    IF '${seed_local_test_data_enabled}' = 'true' THEN
        INSERT INTO user_account (id, username, password_hash, role, status, created_at, updated_at)
        VALUES
            ('11111111-1111-1111-1111-111111111111', 'admin',
             '$2b$12$hVlIat1xQ419kYmkNbCIjew3jGBIfJ1Bwxn.jHr4e4xHhSXmOTsDW', 'ADMIN', 'ACTIVE',
             CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
            ('22222222-2222-2222-2222-222222222222', 'alice',
             '$2a$10$h3aJfQMIcgKJVA/MTKmvre9sBJl/l0EPye79vnVulBGt4o7eC35Ae', 'USER', 'ACTIVE',
             CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (id) DO NOTHING;

        INSERT INTO face_photo (
            id, user_id, obs_bucket, obs_region, obs_object_key, content_type, size_bytes, sha256,
            storage_provider, detect_status, register_status, failure_reason, failure_code, enabled,
            created_by_user_id, created_at, updated_at
        )
        VALUES (
            '33333333-3333-3333-3333-333333333333',
            '22222222-2222-2222-2222-222222222222',
            'local-seed-bucket',
            'local-seed-region',
            'faces/user/22222222-2222-2222-2222-222222222222/33333333-3333-3333-3333-333333333333.jpg',
            'image/jpeg',
            204800,
            '1111111111111111111111111111111111111111111111111111111111111111',
            'MOCK_OBS',
            'PASSED',
            'ACTIVE',
            NULL,
            NULL,
            TRUE,
            '11111111-1111-1111-1111-111111111111',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (id) DO NOTHING;

        INSERT INTO huawei_face_ref (
            id, user_id, face_photo_id, face_set_name, frs_face_id, external_image_id, external_fields, status,
            created_at, updated_at
        )
        VALUES (
            '44444444-4444-4444-4444-444444444444',
            '22222222-2222-2222-2222-222222222222',
            '33333333-3333-3333-3333-333333333333',
            'facecheck-default',
            'seed-face-alice-1',
            '33333333-3333-3333-3333-333333333333',
            '{"userId":"22222222-2222-2222-2222-222222222222","facePhotoId":"33333333-3333-3333-3333-333333333333"}'::jsonb,
            'ACTIVE',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (id) DO NOTHING;

        INSERT INTO attendance_session (
            id, name, description, start_time, end_time, late_after_time, status, qr_token, qr_token_version,
            created_by_user_id, created_at, updated_at
        )
        VALUES (
            '55555555-5555-5555-5555-555555555555',
            '本地调试示例场次',
            '用于 Android smoke、管理员页面联调和本地启动验证。',
            TIMESTAMP '2024-01-01 00:00:00',
            TIMESTAMP '2099-12-31 23:59:59',
            NULL,
            'PUBLISHED',
            'seed-local-session-token',
            1,
            '11111111-1111-1111-1111-111111111111',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (id) DO NOTHING;

        INSERT INTO attendance_checkin_attempt (
            id, session_id, obs_bucket, obs_region, obs_object_key, content_type, size_bytes, sha256,
            storage_provider, status, result_code, failure_reason, frs_request_id, matched_user_id, matched_face_id,
            similarity, idempotency_key, client_ip, device_id, created_at, updated_at, review_note, reviewed,
            reviewed_by_user_id, reviewed_at, retry_count
        )
        VALUES
            (
                '66666666-6666-6666-6666-666666666666',
                '55555555-5555-5555-5555-555555555555',
                'local-seed-bucket',
                'local-seed-region',
                'checkins/session/55555555-5555-5555-5555-555555555555/attempt/66666666-6666-6666-6666-666666666666.jpg',
                'image/jpeg',
                153600,
                '2222222222222222222222222222222222222222222222222222222222222222',
                'MOCK_OBS',
                'SUCCESS',
                'SUCCESS',
                NULL,
                'seed-success-request',
                '22222222-2222-2222-2222-222222222222',
                'seed-face-alice-1',
                92.5,
                'seed-success-idempotency',
                '127.0.0.1',
                'seed-emulator',
                CURRENT_TIMESTAMP - INTERVAL '10 minutes',
                CURRENT_TIMESTAMP - INTERVAL '10 minutes',
                NULL,
                FALSE,
                NULL,
                NULL,
                0
            ),
            (
                '77777777-7777-7777-7777-777777777777',
                '55555555-5555-5555-5555-555555555555',
                'local-seed-bucket',
                'local-seed-region',
                'checkins/session/55555555-5555-5555-5555-555555555555/attempt/77777777-7777-7777-7777-777777777777.jpg',
                'image/jpeg',
                145000,
                '3333333333333333333333333333333333333333333333333333333333333333',
                'MOCK_OBS',
                'FAILED',
                'LOW_CONFIDENCE',
                'The matched face confidence is below the acceptance threshold.',
                'seed-review-request',
                '22222222-2222-2222-2222-222222222222',
                'seed-face-alice-1',
                61.2,
                'seed-review-idempotency',
                '127.0.0.1',
                'seed-emulator',
                CURRENT_TIMESTAMP - INTERVAL '5 minutes',
                CURRENT_TIMESTAMP - INTERVAL '5 minutes',
                '等待管理员复核的示例异常。',
                FALSE,
                NULL,
                NULL,
                0
            )
        ON CONFLICT (id) DO NOTHING;

        INSERT INTO attendance_record (
            id, session_id, user_id, attempt_id, checkin_time, status, similarity, source, created_at
        )
        VALUES (
            '88888888-8888-8888-8888-888888888888',
            '55555555-5555-5555-5555-555555555555',
            '22222222-2222-2222-2222-222222222222',
            '66666666-6666-6666-6666-666666666666',
            CURRENT_TIMESTAMP - INTERVAL '10 minutes',
            'VALID',
            92.5,
            'APP_QR_ANON',
            CURRENT_TIMESTAMP - INTERVAL '10 minutes'
        )
        ON CONFLICT (id) DO NOTHING;
    END IF;
END $$;
