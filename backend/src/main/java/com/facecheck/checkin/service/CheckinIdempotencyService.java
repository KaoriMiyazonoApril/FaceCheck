package com.facecheck.checkin.service;

import com.facecheck.checkin.api.dto.CheckinAttemptResponse;
import com.facecheck.checkin.config.CheckinProperties;
import com.facecheck.infrastructure.redis.RedisKeyFactory;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

@Service
public class CheckinIdempotencyService {

    private static final Logger log = LoggerFactory.getLogger(CheckinIdempotencyService.class);

    private final StringRedisTemplate stringRedisTemplate;
    private final RedisKeyFactory redisKeyFactory;
    private final ObjectMapper objectMapper;
    private final CheckinProperties checkinProperties;

    public CheckinIdempotencyService(
            StringRedisTemplate stringRedisTemplate,
            RedisKeyFactory redisKeyFactory,
            ObjectMapper objectMapper,
            CheckinProperties checkinProperties
    ) {
        this.stringRedisTemplate = stringRedisTemplate;
        this.redisKeyFactory = redisKeyFactory;
        this.objectMapper = objectMapper;
        this.checkinProperties = checkinProperties;
    }

    public Optional<CheckinAttemptResponse> find(String scope, String idempotencyKey) {
        try {
            String payload = stringRedisTemplate.opsForValue().get(redisKeyFactory.checkinIdempotency(scope, idempotencyKey));
            if (payload == null || payload.isBlank()) {
                return Optional.empty();
            }
            return Optional.of(objectMapper.readValue(payload, CheckinAttemptResponse.class));
        } catch (Exception exception) {
            log.warn("Failed to read anonymous check-in idempotency cache", exception);
            return Optional.empty();
        }
    }

    public void store(String scope, String idempotencyKey, CheckinAttemptResponse response, Instant sessionEndTime) {
        try {
            stringRedisTemplate.opsForValue().set(
                    redisKeyFactory.checkinIdempotency(scope, idempotencyKey),
                    objectMapper.writeValueAsString(response),
                    ttl(sessionEndTime)
            );
        } catch (Exception exception) {
            log.warn("Failed to write anonymous check-in idempotency cache", exception);
        }
    }

    private Duration ttl(Instant sessionEndTime) {
        Instant now = Instant.now();
        Instant expiresAt = sessionEndTime.plus(Duration.ofHours(checkinProperties.getIdempotencyTtlHours()));
        if (!expiresAt.isAfter(now)) {
            return Duration.ofHours(checkinProperties.getIdempotencyTtlHours());
        }
        return Duration.between(now, expiresAt);
    }
}
