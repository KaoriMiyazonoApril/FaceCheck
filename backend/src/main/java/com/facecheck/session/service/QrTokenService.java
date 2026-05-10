package com.facecheck.session.service;

import com.facecheck.common.error.BusinessException;
import com.facecheck.common.error.ErrorCode;
import com.facecheck.infrastructure.redis.RedisKeyFactory;
import com.facecheck.session.model.AttendanceSession;
import com.facecheck.session.repo.AttendanceSessionRepository;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
public class QrTokenService {

    private static final Logger log = LoggerFactory.getLogger(QrTokenService.class);
    private static final Duration FALLBACK_CACHE_TTL = Duration.ofHours(24);
    private static final Duration POST_SESSION_GRACE_TTL = Duration.ofHours(24);
    private static final int TOKEN_BYTES = 32;
    private static final int MAX_GENERATION_ATTEMPTS = 10;

    private final AttendanceSessionRepository attendanceSessionRepository;
    private final StringRedisTemplate stringRedisTemplate;
    private final RedisKeyFactory redisKeyFactory;
    private final SecureRandom secureRandom = new SecureRandom();

    public QrTokenService(
            AttendanceSessionRepository attendanceSessionRepository,
            StringRedisTemplate stringRedisTemplate,
            RedisKeyFactory redisKeyFactory
    ) {
        this.attendanceSessionRepository = attendanceSessionRepository;
        this.stringRedisTemplate = stringRedisTemplate;
        this.redisKeyFactory = redisKeyFactory;
    }

    public String generateUniqueToken() {
        for (int attempt = 0; attempt < MAX_GENERATION_ATTEMPTS; attempt++) {
            String token = randomToken();
            if (!attendanceSessionRepository.existsByQrToken(token)) {
                return token;
            }
        }
        throw new BusinessException(ErrorCode.SESSION_QR_GENERATION_FAILED, "Unable to generate a unique QR token");
    }

    public void rotateToken(AttendanceSession session) {
        String previousToken = session.getQrToken();
        session.setQrToken(generateUniqueToken());
        Integer previousVersion = session.getQrTokenVersion();
        session.setQrTokenVersion(previousVersion == null ? 1 : previousVersion + 1);
        evict(previousToken);
        cache(session);
    }

    public void cache(AttendanceSession session) {
        if (!StringUtils.hasText(session.getQrToken())) {
            return;
        }
        try {
            stringRedisTemplate.opsForValue().set(
                    redisKeyFactory.sessionQr(session.getQrToken()),
                    session.getId().toString(),
                    cacheTtl(session)
            );
        } catch (RuntimeException exception) {
            log.warn("Failed to cache QR token for session {}", session.getId(), exception);
        }
    }

    public Optional<AttendanceSession> resolve(String qrToken) {
        Optional<AttendanceSession> cached = resolveFromCache(qrToken);
        if (cached.isPresent()) {
            return cached;
        }

        Optional<AttendanceSession> session = attendanceSessionRepository.findByQrToken(qrToken);
        session.ifPresent(this::cache);
        return session;
    }

    public AttendanceSession requireByToken(String qrToken) {
        return resolve(qrToken)
                .orElseThrow(() -> new BusinessException(ErrorCode.INVALID_QR_TOKEN, "QR token is invalid or expired"));
    }

    public String qrContent(AttendanceSession session) {
        return "facecheck://checkin/session-entry?qrToken=" + session.getQrToken();
    }

    public void evict(String qrToken) {
        if (!StringUtils.hasText(qrToken)) {
            return;
        }
        try {
            stringRedisTemplate.delete(redisKeyFactory.sessionQr(qrToken));
        } catch (RuntimeException exception) {
            log.warn("Failed to evict QR token cache entry", exception);
        }
    }

    private Optional<AttendanceSession> resolveFromCache(String qrToken) {
        try {
            String sessionId = stringRedisTemplate.opsForValue().get(redisKeyFactory.sessionQr(qrToken));
            if (!StringUtils.hasText(sessionId)) {
                return Optional.empty();
            }

            Optional<AttendanceSession> session = attendanceSessionRepository.findById(UUID.fromString(sessionId))
                    .filter(saved -> qrToken.equals(saved.getQrToken()));
            if (session.isEmpty()) {
                evict(qrToken);
            }
            return session;
        } catch (IllegalArgumentException exception) {
            evict(qrToken);
            return Optional.empty();
        } catch (RuntimeException exception) {
            log.warn("Failed to resolve QR token from Redis cache", exception);
            return Optional.empty();
        }
    }

    private Duration cacheTtl(AttendanceSession session) {
        Instant now = Instant.now();
        Instant expiresAt = session.getEndTime().plus(POST_SESSION_GRACE_TTL);
        if (!expiresAt.isAfter(now)) {
            return FALLBACK_CACHE_TTL;
        }
        return Duration.between(now, expiresAt);
    }

    private String randomToken() {
        byte[] bytes = new byte[TOKEN_BYTES];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }
}
