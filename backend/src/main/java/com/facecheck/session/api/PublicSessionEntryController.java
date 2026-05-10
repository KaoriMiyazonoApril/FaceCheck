package com.facecheck.session.api;

import com.facecheck.common.api.ApiResponse;
import com.facecheck.session.api.dto.SessionEntryRequest;
import com.facecheck.session.api.dto.SessionEntryResponse;
import com.facecheck.session.service.AttendanceSessionService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/public/checkin")
public class PublicSessionEntryController {

    private final AttendanceSessionService attendanceSessionService;

    public PublicSessionEntryController(AttendanceSessionService attendanceSessionService) {
        this.attendanceSessionService = attendanceSessionService;
    }

    @PostMapping("/session-entry")
    public ApiResponse<SessionEntryResponse> resolveSessionEntry(@Valid @RequestBody SessionEntryRequest request) {
        return ApiResponse.success(attendanceSessionService.resolveSessionEntry(request.qrToken()));
    }
}
