package com.facecheck.admin.service;

import com.facecheck.admin.api.dto.AdminCreateUserRequest;
import com.facecheck.admin.api.dto.AdminUpdateUserRequest;
import com.facecheck.common.error.BusinessException;
import com.facecheck.common.error.ErrorCode;
import com.facecheck.auth.service.PasswordService;
import com.facecheck.identity.api.dto.UserProfileResponse;
import com.facecheck.identity.model.User;
import com.facecheck.identity.model.UserStatus;
import com.facecheck.identity.repo.UserRepository;
import com.facecheck.identity.service.UserProfileService;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class AdminUserService {

    private final UserRepository userRepository;
    private final PasswordService passwordService;
    private final AuditLogService auditLogService;

    public AdminUserService(
            UserRepository userRepository,
            PasswordService passwordService,
            AuditLogService auditLogService
    ) {
        this.userRepository = userRepository;
        this.passwordService = passwordService;
        this.auditLogService = auditLogService;
    }

    @Transactional(readOnly = true)
    public List<UserProfileResponse> listUsers() {
        return userRepository.findAllByOrderByCreatedAtDesc().stream()
                .map(UserProfileService::toResponse)
                .toList();
    }

    @Transactional
    public UserProfileResponse createUser(AdminCreateUserRequest request) {
        if (userRepository.existsByUsername(request.username().trim())) {
            throw new BusinessException(ErrorCode.DUPLICATE_USERNAME, "Username already exists");
        }

        User user = new User();
        user.setUsername(request.username().trim());
        user.setPasswordHash(passwordService.hash(request.password()));
        user.setRole(request.role());
        user.setStatus(UserStatus.ACTIVE);
        User saved = userRepository.save(user);
        auditLogService.recordCurrentActor(
                "ADMIN_USER_CREATE",
                "USER_ACCOUNT",
                saved.getId(),
                "Administrator created a user account.",
                Map.of("username", saved.getUsername(), "role", saved.getRole().name(), "status", saved.getStatus().name())
        );
        return UserProfileService.toResponse(saved);
    }

    @Transactional
    public UserProfileResponse updateUser(UUID userId, AdminUpdateUserRequest request) {
        User user = findUser(userId);
        Map<String, Object> changes = new LinkedHashMap<>();
        if (StringUtils.hasText(request.username())) {
            String username = request.username().trim();
            if (userRepository.existsByUsernameAndIdNot(username, userId)) {
                throw new BusinessException(ErrorCode.DUPLICATE_USERNAME, "Username already exists");
            }
            user.setUsername(username);
            changes.put("username", username);
        }
        if (StringUtils.hasText(request.password())) {
            user.setPasswordHash(passwordService.hash(request.password()));
            changes.put("passwordChanged", true);
        }
        if (request.role() != null) {
            user.setRole(request.role());
            changes.put("role", request.role().name());
        }
        if (request.status() != null) {
            user.setStatus(request.status());
            changes.put("status", request.status().name());
        }
        auditLogService.recordCurrentActor(
                "ADMIN_USER_UPDATE",
                "USER_ACCOUNT",
                user.getId(),
                "Administrator updated a user account.",
                changes
        );
        return UserProfileService.toResponse(user);
    }

    @Transactional
    public UserProfileResponse disableUser(UUID userId) {
        User user = findUser(userId);
        user.setStatus(UserStatus.DISABLED);
        auditLogService.recordCurrentActor(
                "ADMIN_USER_DISABLE",
                "USER_ACCOUNT",
                user.getId(),
                "Administrator disabled a user account.",
                Map.of("username", user.getUsername(), "status", user.getStatus().name())
        );
        return UserProfileService.toResponse(user);
    }

    private User findUser(UUID userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "User does not exist"));
    }
}
