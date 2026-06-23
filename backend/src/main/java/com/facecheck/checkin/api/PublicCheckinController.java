package com.facecheck.checkin.api;

import com.facecheck.checkin.api.dto.CheckinAttemptResponse;
import com.facecheck.checkin.model.CheckinStatus;
import com.facecheck.checkin.service.CheckinService;
import com.facecheck.common.api.ApiResponse;
import jakarta.validation.constraints.NotBlank;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import jakarta.servlet.http.HttpServletRequest;

@Validated
@RestController
@RequestMapping("/api/public/checkin")
public class PublicCheckinController {

    private final CheckinService checkinService;

    public PublicCheckinController(CheckinService checkinService) {
        this.checkinService = checkinService;
    }

    @PostMapping("/attempts")
    public ResponseEntity<ApiResponse<CheckinAttemptResponse>> submit(
            @RequestParam @NotBlank String qrToken,
            @RequestParam @NotBlank String idempotencyKey,
            @RequestParam(required = false) String deviceId,
            @RequestParam("file") MultipartFile file,
            HttpServletRequest request
    ) {
        CheckinAttemptResponse response =
                checkinService.submit(qrToken, idempotencyKey, deviceId, request.getRemoteAddr(), file);
        HttpStatus status = response.status() == CheckinStatus.PROCESSING ? HttpStatus.ACCEPTED : HttpStatus.OK;
        return ResponseEntity.status(status).body(ApiResponse.success(response));
    }

    @GetMapping("/attempts/{attemptId}")
    public ApiResponse<CheckinAttemptResponse> getAttempt(
            @PathVariable UUID attemptId,
            @RequestParam @NotBlank String qrToken
    ) {
        return ApiResponse.success(checkinService.getAttempt(qrToken, attemptId));
    }
}
