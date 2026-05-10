package com.facecheck.infrastructure.redis;

import org.springframework.stereotype.Component;

@Component
public class RedisKeyFactory {

    public String authBlacklist(String jti) {
        return "auth:blacklist:" + jti;
    }

    public String checkinIdempotency(String idempotencyKey) {
        return "checkin:idempotency:" + idempotencyKey;
    }

    public String sessionQr(String qrToken) {
        return "session:qr:" + qrToken;
    }
}
