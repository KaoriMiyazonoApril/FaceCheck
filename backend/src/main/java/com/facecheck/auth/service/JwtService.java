package com.facecheck.auth.service;

import com.facecheck.identity.model.User;
import com.facecheck.identity.model.UserRole;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class JwtService {

    private static final Base64.Encoder BASE64_URL_ENCODER = Base64.getUrlEncoder().withoutPadding();
    private static final Base64.Decoder BASE64_URL_DECODER = Base64.getUrlDecoder();
    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {
    };

    private final ObjectMapper objectMapper;
    private final Clock clock;
    private final String issuer;
    private final String secret;
    private final long expiresMinutes;

    public JwtService(
            ObjectMapper objectMapper,
            Clock clock,
            @Value("${facecheck.security.jwt.issuer}") String issuer,
            @Value("${facecheck.security.jwt.secret}") String secret,
            @Value("${facecheck.security.jwt.expires-minutes}") long expiresMinutes
    ) {
        this.objectMapper = objectMapper;
        this.clock = clock;
        this.issuer = issuer;
        this.secret = secret;
        this.expiresMinutes = expiresMinutes;
    }

    public IssuedToken issue(User user) {
        Instant issuedAt = Instant.now(clock).truncatedTo(ChronoUnit.SECONDS);
        Instant expiresAt = issuedAt.plus(expiresMinutes, ChronoUnit.MINUTES);
        String jti = UUID.randomUUID().toString();

        Map<String, Object> header = Map.of(
                "alg", "HS256",
                "typ", "JWT"
        );
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("iss", issuer);
        payload.put("sub", user.getUsername());
        payload.put("userId", user.getId().toString());
        payload.put("role", user.getRole().name());
        payload.put("jti", jti);
        payload.put("iat", issuedAt.getEpochSecond());
        payload.put("exp", expiresAt.getEpochSecond());

        try {
            String encodedHeader = encode(objectMapper.writeValueAsBytes(header));
            String encodedPayload = encode(objectMapper.writeValueAsBytes(payload));
            String signingInput = encodedHeader + "." + encodedPayload;
            String signature = sign(signingInput);
            return new IssuedToken(signingInput + "." + signature, expiresAt.getEpochSecond() - issuedAt.getEpochSecond());
        } catch (Exception exception) {
            throw new IllegalStateException("Failed to issue JWT", exception);
        }
    }

    public TokenClaims parse(String token) {
        String[] segments = token.split("\\.");
        if (segments.length != 3) {
            throw new InvalidTokenException("Malformed JWT");
        }

        String signingInput = segments[0] + "." + segments[1];
        String expectedSignature = sign(signingInput);
        if (!MessageDigest.isEqual(expectedSignature.getBytes(StandardCharsets.UTF_8), segments[2].getBytes(StandardCharsets.UTF_8))) {
            throw new InvalidTokenException("Invalid JWT signature");
        }

        try {
            Map<String, Object> payload = objectMapper.readValue(BASE64_URL_DECODER.decode(segments[1]), MAP_TYPE);
            Instant expiresAt = Instant.ofEpochSecond(numberValue(payload.get("exp")));
            Instant issuedAt = Instant.ofEpochSecond(numberValue(payload.get("iat")));
            if (expiresAt.isBefore(Instant.now(clock))) {
                throw new InvalidTokenException("JWT is expired");
            }
            if (!issuer.equals(payload.get("iss"))) {
                throw new InvalidTokenException("JWT issuer mismatch");
            }

            return new TokenClaims(
                    UUID.fromString(stringValue(payload.get("userId"))),
                    stringValue(payload.get("sub")),
                    UserRole.valueOf(stringValue(payload.get("role"))),
                    stringValue(payload.get("jti")),
                    issuedAt,
                    expiresAt
            );
        } catch (InvalidTokenException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new InvalidTokenException("Failed to parse JWT", exception);
        }
    }

    private String sign(String payload) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return encode(mac.doFinal(payload.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new IllegalStateException("Failed to sign JWT", exception);
        }
    }

    private String encode(byte[] value) {
        return BASE64_URL_ENCODER.encodeToString(value);
    }

    private static long numberValue(Object value) {
        return ((Number) value).longValue();
    }

    private static String stringValue(Object value) {
        return String.valueOf(value);
    }

    public record IssuedToken(String accessToken, long expiresInSeconds) {
    }

    public record TokenClaims(
            UUID userId,
            String username,
            UserRole role,
            String jti,
            Instant issuedAt,
            Instant expiresAt
    ) {
    }

    public static class InvalidTokenException extends RuntimeException {

        public InvalidTokenException(String message) {
            super(message);
        }

        public InvalidTokenException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
