package com.facecheck.session.api;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.facecheck.auth.filter.JwtAuthenticationFilter;
import com.facecheck.common.error.BusinessException;
import com.facecheck.common.error.ErrorCode;
import com.facecheck.common.error.GlobalExceptionHandler;
import com.facecheck.session.api.dto.AttendanceSessionSummaryResponse;
import com.facecheck.session.api.dto.QrTokenResponse;
import com.facecheck.session.api.dto.SessionEntryResponse;
import com.facecheck.session.model.AttendanceSessionStatus;
import com.facecheck.session.service.AttendanceSessionService;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest({AdminAttendanceSessionController.class, PublicSessionEntryController.class})
@AutoConfigureMockMvc(addFilters = false)
@ActiveProfiles("test")
@Import(GlobalExceptionHandler.class)
class AttendanceSessionControllerContractTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private AttendanceSessionService attendanceSessionService;

    @MockBean
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    @Test
    void shouldExposeAdminSessionLifecycleContracts() throws Exception {
        UUID sessionId = UUID.randomUUID();
        AttendanceSessionSummaryResponse summary = summary(sessionId, AttendanceSessionStatus.DRAFT, 1);
        AttendanceSessionSummaryResponse published = summary(sessionId, AttendanceSessionStatus.PUBLISHED, 1);
        AttendanceSessionSummaryResponse closed = summary(sessionId, AttendanceSessionStatus.CLOSED, 1);
        AttendanceSessionSummaryResponse canceled = summary(sessionId, AttendanceSessionStatus.CANCELED, 1);
        QrTokenResponse currentQr = new QrTokenResponse(
                sessionId,
                "token-v1",
                "facecheck://checkin/session-entry?qrToken=dG9rZW4tdjE"
        );
        QrTokenResponse rotatedQr = new QrTokenResponse(
                sessionId,
                "token-v2",
                "facecheck://checkin/session-entry?qrToken=dG9rZW4tdjI"
        );

        given(attendanceSessionService.listSessions()).willReturn(List.of(summary));
        given(attendanceSessionService.createSession(any(), any())).willReturn(summary);
        given(attendanceSessionService.updateSession(any(), any())).willReturn(summary);
        given(attendanceSessionService.publishSession(sessionId)).willReturn(published);
        given(attendanceSessionService.closeSession(sessionId)).willReturn(closed);
        given(attendanceSessionService.cancelSession(sessionId)).willReturn(canceled);
        given(attendanceSessionService.currentQrToken(sessionId)).willReturn(currentQr);
        given(attendanceSessionService.resetQrToken(sessionId)).willReturn(rotatedQr);

        mockMvc.perform(get("/api/admin/sessions"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].sessionId").value(sessionId.toString()))
                .andExpect(jsonPath("$.data[0].status").value("DRAFT"))
                .andExpect(jsonPath("$.data[0].qrToken").doesNotExist());

        mockMvc.perform(post("/api/admin/sessions")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name":"Morning Roll Call",
                                  "description":"Main building lobby",
                                  "startTime":"2026-05-10T08:00:00Z",
                                  "endTime":"2026-05-10T09:00:00Z"
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.sessionId").value(sessionId.toString()))
                .andExpect(jsonPath("$.data.name").value("Morning Roll Call"))
                .andExpect(jsonPath("$.data.qrTokenVersion").value(1));

        mockMvc.perform(put("/api/admin/sessions/{sessionId}", sessionId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name":"Morning Roll Call",
                                  "description":"Updated lobby",
                                  "startTime":"2026-05-10T08:15:00Z",
                                  "endTime":"2026-05-10T09:15:00Z"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("DRAFT"));

        mockMvc.perform(post("/api/admin/sessions/{sessionId}/publish", sessionId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("PUBLISHED"));

        mockMvc.perform(post("/api/admin/sessions/{sessionId}/close", sessionId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("CLOSED"));

        mockMvc.perform(post("/api/admin/sessions/{sessionId}/cancel", sessionId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("CANCELED"));

        mockMvc.perform(get("/api/admin/sessions/{sessionId}/qr-token", sessionId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.sessionId").value(sessionId.toString()))
                .andExpect(jsonPath("$.data.qrToken").value("token-v1"));

        mockMvc.perform(post("/api/admin/sessions/{sessionId}/qr-token/reset", sessionId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.sessionId").value(sessionId.toString()))
                .andExpect(jsonPath("$.data.qrToken").value("token-v2"))
                .andExpect(jsonPath("$.data.qrContent").isString());
    }

    @Test
    void shouldExposePublicSessionEntryContracts() throws Exception {
        UUID sessionId = UUID.randomUUID();
        given(attendanceSessionService.resolveSessionEntry("token-ok"))
                .willReturn(new SessionEntryResponse(
                        sessionId,
                        "Morning Roll Call",
                        "Main building lobby",
                        Instant.parse("2026-05-10T08:00:00Z"),
                        Instant.parse("2026-05-10T09:00:00Z"),
                        AttendanceSessionStatus.PUBLISHED,
                        true,
                        null,
                        null
                ));
        given(attendanceSessionService.resolveSessionEntry("token-closed"))
                .willReturn(new SessionEntryResponse(
                        sessionId,
                        "Morning Roll Call",
                        "Main building lobby",
                        Instant.parse("2026-05-10T08:00:00Z"),
                        Instant.parse("2026-05-10T09:00:00Z"),
                        AttendanceSessionStatus.CLOSED,
                        false,
                        "SESSION_CLOSED",
                        "The session has already been closed."
                ));
        given(attendanceSessionService.resolveSessionEntry("bad-token"))
                .willThrow(new BusinessException(ErrorCode.INVALID_QR_TOKEN, "QR token is invalid or expired"));

        mockMvc.perform(post("/api/public/checkin/session-entry")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"qrToken":"token-ok"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.sessionId").value(sessionId.toString()))
                .andExpect(jsonPath("$.data.canCheckin").value(true))
                .andExpect(jsonPath("$.data.refusalCode").doesNotExist());

        mockMvc.perform(post("/api/public/checkin/session-entry")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"qrToken":"token-closed"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("CLOSED"))
                .andExpect(jsonPath("$.data.canCheckin").value(false))
                .andExpect(jsonPath("$.data.refusalCode").value("SESSION_CLOSED"));

        mockMvc.perform(post("/api/public/checkin/session-entry")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"qrToken":"bad-token"}
                                """))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("INVALID_QR_TOKEN"));
    }

    private AttendanceSessionSummaryResponse summary(UUID sessionId, AttendanceSessionStatus status, int qrTokenVersion) {
        return new AttendanceSessionSummaryResponse(
                sessionId,
                "Morning Roll Call",
                "Main building lobby",
                Instant.parse("2026-05-10T08:00:00Z"),
                Instant.parse("2026-05-10T09:00:00Z"),
                null,
                status,
                qrTokenVersion,
                Instant.parse("2026-05-10T07:30:00Z")
        );
    }
}
