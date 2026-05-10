package com.facecheck.session.api;

import com.facecheck.auth.security.AdminOnly;
import com.facecheck.common.api.ApiResponse;
import com.facecheck.session.api.dto.AttendanceSessionSummaryResponse;
import com.facecheck.session.api.dto.CreateAttendanceSessionRequest;
import com.facecheck.session.api.dto.QrTokenResponse;
import com.facecheck.session.api.dto.UpdateAttendanceSessionRequest;
import com.facecheck.session.service.AttendanceSessionService;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/sessions")
@AdminOnly
public class AdminAttendanceSessionController {

    private final AttendanceSessionService attendanceSessionService;

    public AdminAttendanceSessionController(AttendanceSessionService attendanceSessionService) {
        this.attendanceSessionService = attendanceSessionService;
    }

    @GetMapping
    public ApiResponse<List<AttendanceSessionSummaryResponse>> listSessions() {
        return ApiResponse.success(attendanceSessionService.listSessions());
    }

    @PostMapping
    public ResponseEntity<ApiResponse<AttendanceSessionSummaryResponse>> createSession(
            Authentication authentication,
            @Valid @RequestBody CreateAttendanceSessionRequest request
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(attendanceSessionService.createSession(authentication, request)));
    }

    @PutMapping("/{sessionId}")
    public ApiResponse<AttendanceSessionSummaryResponse> updateSession(
            @PathVariable UUID sessionId,
            @Valid @RequestBody UpdateAttendanceSessionRequest request
    ) {
        return ApiResponse.success(attendanceSessionService.updateSession(sessionId, request));
    }

    @PostMapping("/{sessionId}/publish")
    public ApiResponse<AttendanceSessionSummaryResponse> publishSession(@PathVariable UUID sessionId) {
        return ApiResponse.success(attendanceSessionService.publishSession(sessionId));
    }

    @PostMapping("/{sessionId}/close")
    public ApiResponse<AttendanceSessionSummaryResponse> closeSession(@PathVariable UUID sessionId) {
        return ApiResponse.success(attendanceSessionService.closeSession(sessionId));
    }

    @PostMapping("/{sessionId}/cancel")
    public ApiResponse<AttendanceSessionSummaryResponse> cancelSession(@PathVariable UUID sessionId) {
        return ApiResponse.success(attendanceSessionService.cancelSession(sessionId));
    }

    @GetMapping("/{sessionId}/qr-token")
    public ApiResponse<QrTokenResponse> currentQrToken(@PathVariable UUID sessionId) {
        return ApiResponse.success(attendanceSessionService.currentQrToken(sessionId));
    }

    @PostMapping("/{sessionId}/qr-token/reset")
    public ApiResponse<QrTokenResponse> resetQrToken(@PathVariable UUID sessionId) {
        return ApiResponse.success(attendanceSessionService.resetQrToken(sessionId));
    }
}
