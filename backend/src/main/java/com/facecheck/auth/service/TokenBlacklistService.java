package com.facecheck.auth.service;

import com.facecheck.infrastructure.redis.RedisKeyFactory;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

@Service
public class TokenBlacklistService {

    private final StringRedisTemplate redisTemplate;
    private final RedisKeyFactory redisKeyFactory;
    private final Clock clock;

    public TokenBlacklistService(StringRedisTemplate redisTemplate, RedisKeyFactory redisKeyFactory, Clock clock) {
        this.redisTemplate = redisTemplate;
        this.redisKeyFactory = redisKeyFactory;
        this.clock = clock;
    }

    public void blacklist(String jti, Instant expiresAt) {
        Duration ttl = Duration.between(Instant.now(clock), expiresAt);
        if (ttl.isNegative() || ttl.isZero()) {
            return;
        }
        redisTemplate.opsForValue().set(redisKeyFactory.authBlacklist(jti), "1", ttl);
    }

    public boolean isBlacklisted(String jti) {
        return Boolean.TRUE.equals(redisTemplate.hasKey(redisKeyFactory.authBlacklist(jti)));
    }
}
