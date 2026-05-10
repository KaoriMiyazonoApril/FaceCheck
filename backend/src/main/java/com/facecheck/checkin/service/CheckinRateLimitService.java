package com.facecheck.checkin.service;

import com.facecheck.checkin.config.CheckinProperties;
import com.facecheck.common.error.BusinessException;
import com.facecheck.common.error.ErrorCode;
import com.facecheck.infrastructure.redis.RedisKeyFactory;
import java.time.Duration;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
public class CheckinRateLimitService {

    private static final Logger log = LoggerFactory.getLogger(CheckinRateLimitService.class);

    private final StringRedisTemplate stringRedisTemplate;
    private final RedisKeyFactory redisKeyFactory;
    private final CheckinProperties checkinProperties;

    public CheckinRateLimitService(
            StringRedisTemplate stringRedisTemplate,
            RedisKeyFactory redisKeyFactory,
            CheckinProperties checkinProperties
    ) {
        this.stringRedisTemplate = stringRedisTemplate;
        this.redisKeyFactory = redisKeyFactory;
        this.checkinProperties = checkinProperties;
    }

    public void checkAllowed(UUID sessionId, String clientIp, String deviceId) {
        if (StringUtils.hasText(clientIp) && exceeded(sessionId, "ip:" + clientIp)) {
            throw new BusinessException(ErrorCode.RATE_LIMITED, "Anonymous check-in requests are too frequent.");
        }
        if (StringUtils.hasText(deviceId) && exceeded(sessionId, "device:" + deviceId)) {
            throw new BusinessException(ErrorCode.RATE_LIMITED, "Anonymous check-in requests are too frequent.");
        }
    }

    private boolean exceeded(UUID sessionId, String subject) {
        try {
            String key = redisKeyFactory.checkinRate(sessionId, subject);
            Long current = stringRedisTemplate.opsForValue().increment(key);
            if (current != null && current == 1L) {
                stringRedisTemplate.expire(key, Duration.ofSeconds(checkinProperties.getRateLimitWindowSeconds()));
            }
            return current != null && current > checkinProperties.getRateLimitMaxRequests();
        } catch (RuntimeException exception) {
            log.warn("Failed to apply anonymous check-in rate limit for session {}", sessionId, exception);
            return false;
        }
    }
}
