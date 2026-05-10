package com.facecheck.session.api.dto;

import jakarta.validation.constraints.NotBlank;

public record SessionEntryRequest(
        @NotBlank String qrToken
) {
}
