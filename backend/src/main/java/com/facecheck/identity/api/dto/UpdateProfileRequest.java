package com.facecheck.identity.api.dto;

import jakarta.validation.constraints.Size;

public record UpdateProfileRequest(
        @Size(min = 3, max = 64) String username,
        @Size(min = 8, max = 72) String password
) {
}
