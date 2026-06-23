package com.facecheck.checkin.api;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.facecheck.auth.filter.JwtAuthenticationFilter;
import com.facecheck.checkin.api.dto.CheckinAttemptResponse;
import com.facecheck.checkin.model.CheckinStatus;
import com.facecheck.checkin.service.CheckinService;
import com.facecheck.common.error.BusinessException;
import com.facecheck.common.error.ErrorCode;
import com.facecheck.common.error.GlobalExceptionHandler;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(PublicCheckinController.class)
@AutoConfigureMockMvc(addFilters = false)
@Import(GlobalExceptionHandler.class)
@ActiveProfiles("test")
class PublicCheckinControllerContractTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private CheckinService checkinService;

    @MockBean
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    @Test
    void shouldExposeAnonymousSubmitAndQueryContracts() throws Exception {
        UUID attemptId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();

        given(checkinService.submit(eq("token-1"), eq("idem-1"), eq("device-1"), any(), any()))
                .willReturn(new CheckinAttemptResponse(
                        attemptId,
                        sessionId,
                        "Morning Roll Call",
                        CheckinStatus.PROCESSING,
                        "PROCESSING",
                        "The check-in is still being processed.",
                        null,
                        null,
                        3
                ));
        given(checkinService.getAttempt("token-1", attemptId))
                .willReturn(new CheckinAttemptResponse(
                        attemptId,
                        sessionId,
                        "Morning Roll Call",
                        CheckinStatus.SUCCESS,
                        "SUCCESS",
                        "Check-in completed successfully.",
                        Instant.parse("2026-05-10T08:30:00Z"),
                        "u***r",
                        null
                ));

        mockMvc.perform(multipart("/api/public/checkin/attempts")
                        .file(new MockMultipartFile("file", "checkin.png", "image/png", "png".getBytes()))
                        .param("qrToken", "token-1")
                        .param("idempotencyKey", "idem-1")
                        .param("deviceId", "device-1"))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.attemptId").value(attemptId.toString()))
                .andExpect(jsonPath("$.data.sessionId").value(sessionId.toString()))
                .andExpect(jsonPath("$.data.sessionName").value("Morning Roll Call"))
                .andExpect(jsonPath("$.data.status").value("PROCESSING"))
                .andExpect(jsonPath("$.data.resultCode").value("PROCESSING"))
                .andExpect(jsonPath("$.data.nextPollAfterSeconds").value(3))
                .andExpect(jsonPath("$.data.maskedUsername").doesNotExist())
                .andExpect(jsonPath("$.data.similarity").doesNotExist())
                .andExpect(jsonPath("$.data.userId").doesNotExist())
                .andExpect(jsonPath("$.data.username").doesNotExist());

        mockMvc.perform(get("/api/public/checkin/attempts/{attemptId}", attemptId)
                        .param("qrToken", "token-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.attemptId").value(attemptId.toString()))
                .andExpect(jsonPath("$.data.status").value("SUCCESS"))
                .andExpect(jsonPath("$.data.resultCode").value("SUCCESS"))
                .andExpect(jsonPath("$.data.checkinTime").value("2026-05-10T08:30:00Z"))
                .andExpect(jsonPath("$.data.maskedUsername").value("u***r"))
                .andExpect(jsonPath("$.data.similarity").doesNotExist())
                .andExpect(jsonPath("$.data.userId").doesNotExist())
                .andExpect(jsonPath("$.data.username").doesNotExist());
    }

    @Test
    void shouldRejectMissingMultipartFieldsAndUnknownAttempts() throws Exception {
        UUID attemptId = UUID.randomUUID();
        given(checkinService.getAttempt("token-1", attemptId))
                .willThrow(new BusinessException(ErrorCode.NOT_FOUND, "Check-in attempt does not exist"));

        mockMvc.perform(multipart("/api/public/checkin/attempts")
                        .file(new MockMultipartFile("file", "checkin.png", "image/png", "png".getBytes()))
                        .param("idempotencyKey", "idem-1"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));

        mockMvc.perform(get("/api/public/checkin/attempts/{attemptId}", attemptId)
                        .param("qrToken", "token-1"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));
    }

    @Test
    void shouldRequireQrTokenWhenQueryingAnonymousAttempt() throws Exception {
        mockMvc.perform(get("/api/public/checkin/attempts/{attemptId}", UUID.randomUUID()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));
    }
}
