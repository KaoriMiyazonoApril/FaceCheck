package com.facecheck.admin.api;

import com.facecheck.admin.api.dto.AdminCreateUserRequest;
import com.facecheck.admin.api.dto.AdminUpdateUserRequest;
import com.facecheck.admin.service.AdminUserService;
import com.facecheck.auth.security.AdminOnly;
import com.facecheck.common.api.ApiResponse;
import com.facecheck.identity.api.dto.UserProfileResponse;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/users")
@AdminOnly
public class AdminUserController {

    private final AdminUserService adminUserService;

    public AdminUserController(AdminUserService adminUserService) {
        this.adminUserService = adminUserService;
    }

    @GetMapping
    public ApiResponse<List<UserProfileResponse>> listUsers() {
        return ApiResponse.success(adminUserService.listUsers());
    }

    @PostMapping
    public ApiResponse<UserProfileResponse> createUser(@Valid @RequestBody AdminCreateUserRequest request) {
        return ApiResponse.success(adminUserService.createUser(request));
    }

    @PutMapping("/{userId}")
    public ApiResponse<UserProfileResponse> updateUser(
            @PathVariable UUID userId,
            @Valid @RequestBody AdminUpdateUserRequest request
    ) {
        return ApiResponse.success(adminUserService.updateUser(userId, request));
    }

    @PostMapping("/{userId}/disable")
    public ApiResponse<UserProfileResponse> disableUser(@PathVariable UUID userId) {
        return ApiResponse.success(adminUserService.disableUser(userId));
    }
}
