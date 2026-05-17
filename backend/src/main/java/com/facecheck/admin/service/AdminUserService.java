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
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class AdminUserService {

    private final UserRepository userRepository;
    private final PasswordService passwordService;

    public AdminUserService(UserRepository userRepository, PasswordService passwordService) {
        this.userRepository = userRepository;
        this.passwordService = passwordService;
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
        return UserProfileService.toResponse(userRepository.save(user));
    }

    @Transactional
    public UserProfileResponse updateUser(UUID userId, AdminUpdateUserRequest request) {
        User user = findUser(userId);
        if (StringUtils.hasText(request.username())) {
            String username = request.username().trim();
            if (userRepository.existsByUsernameAndIdNot(username, userId)) {
                throw new BusinessException(ErrorCode.DUPLICATE_USERNAME, "Username already exists");
            }
            user.setUsername(username);
        }
        if (StringUtils.hasText(request.password())) {
            user.setPasswordHash(passwordService.hash(request.password()));
        }
        if (request.role() != null) {
            user.setRole(request.role());
        }
        if (request.status() != null) {
            user.setStatus(request.status());
        }
        return UserProfileService.toResponse(user);
    }

    @Transactional
    public UserProfileResponse disableUser(UUID userId) {
        User user = findUser(userId);
        user.setStatus(UserStatus.DISABLED);
        return UserProfileService.toResponse(user);
    }

    private User findUser(UUID userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "User does not exist"));
    }
}
