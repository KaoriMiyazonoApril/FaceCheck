package com.facecheck.auth.security;

import com.facecheck.identity.model.UserRole;
import java.time.Instant;
import java.util.UUID;

public record AuthenticatedUser(
        UUID userId,
        String username,
        UserRole role,
        String jti,
        Instant expiresAt
) {
}
