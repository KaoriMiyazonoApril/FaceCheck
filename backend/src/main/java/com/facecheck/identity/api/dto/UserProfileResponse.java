package com.facecheck.identity.api.dto;

import com.facecheck.identity.model.UserRole;
import com.facecheck.identity.model.UserStatus;
import java.util.UUID;

public record UserProfileResponse(
        UUID userId,
        String username,
        UserRole role,
        UserStatus status
) {
}
