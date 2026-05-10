package com.facecheck.session.api.dto;

import java.util.UUID;

public record QrTokenResponse(
        UUID sessionId,
        String qrToken,
        String qrContent
) {
}
