package com.facecheck.identity.service;

import com.facecheck.auth.security.CurrentUserAccess;
import com.facecheck.auth.service.PasswordService;
import com.facecheck.common.error.BusinessException;
import com.facecheck.common.error.ErrorCode;
import com.facecheck.identity.api.dto.UpdateProfileRequest;
import com.facecheck.identity.api.dto.UserProfileResponse;
import com.facecheck.identity.model.User;
import com.facecheck.identity.repo.UserRepository;
import java.util.UUID;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class UserProfileService {

    private final UserRepository userRepository;
    private final PasswordService passwordService;
    private final CurrentUserAccess currentUserAccess;

    public UserProfileService(
            UserRepository userRepository,
            PasswordService passwordService,
            CurrentUserAccess currentUserAccess
    ) {
        this.userRepository = userRepository;
        this.passwordService = passwordService;
        this.currentUserAccess = currentUserAccess;
    }

    @Transactional(readOnly = true)
    public UserProfileResponse getCurrentProfile(Authentication authentication) {
        return toResponse(loadCurrentUser(authentication));
    }

    @Transactional
    public UserProfileResponse updateCurrentProfile(Authentication authentication, UpdateProfileRequest request) {
        User user = loadCurrentUser(authentication);
        if (StringUtils.hasText(request.username())) {
            String username = request.username().trim();
            if (userRepository.existsByUsernameAndIdNot(username, user.getId())) {
                throw new BusinessException(ErrorCode.DUPLICATE_USERNAME, "Username already exists");
            }
            user.setUsername(username);
        }
        if (StringUtils.hasText(request.password())) {
            user.setPasswordHash(passwordService.hash(request.password()));
        }
        return toResponse(user);
    }

    private User loadCurrentUser(Authentication authentication) {
        UUID userId = currentUserAccess.requireUserId(authentication);
        return userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "User does not exist"));
    }

    public static UserProfileResponse toResponse(User user) {
        return new UserProfileResponse(user.getId(), user.getUsername(), user.getRole(), user.getStatus());
    }
}
