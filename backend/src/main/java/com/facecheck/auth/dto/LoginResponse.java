package com.facecheck.auth.dto;

import com.facecheck.identity.model.UserRole;
import com.facecheck.identity.api.dto.UserProfileResponse;

public record LoginResponse(
        String accessToken,
        String tokenType,
        long expiresIn,
        UserRole role,
        UserProfileResponse user
) {
}
