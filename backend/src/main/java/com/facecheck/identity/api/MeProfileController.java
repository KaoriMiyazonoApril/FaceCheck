package com.facecheck.identity.api;

import com.facecheck.common.api.ApiResponse;
import com.facecheck.identity.api.dto.UpdateProfileRequest;
import com.facecheck.identity.api.dto.UserProfileResponse;
import com.facecheck.identity.service.UserProfileService;
import jakarta.validation.Valid;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/me/profile")
public class MeProfileController {

    private final UserProfileService userProfileService;

    public MeProfileController(UserProfileService userProfileService) {
        this.userProfileService = userProfileService;
    }

    @GetMapping
    public ApiResponse<UserProfileResponse> getProfile(Authentication authentication) {
        return ApiResponse.success(userProfileService.getCurrentProfile(authentication));
    }

    @PutMapping
    public ApiResponse<UserProfileResponse> updateProfile(
            Authentication authentication,
            @Valid @RequestBody UpdateProfileRequest request
    ) {
        return ApiResponse.success(userProfileService.updateCurrentProfile(authentication, request));
    }
}
