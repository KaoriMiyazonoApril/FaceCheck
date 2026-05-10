package com.facecheck.admin.api.dto;

import com.facecheck.identity.model.UserRole;
import com.facecheck.identity.model.UserStatus;
import jakarta.validation.constraints.Size;

public record AdminUpdateUserRequest(
        @Size(min = 3, max = 64) String username,
        @Size(min = 8, max = 72) String password,
        UserRole role,
        UserStatus status
) {
}
