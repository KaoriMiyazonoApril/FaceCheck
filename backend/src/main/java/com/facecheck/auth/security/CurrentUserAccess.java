package com.facecheck.auth.security;

import com.facecheck.common.error.BusinessException;
import com.facecheck.common.error.ErrorCode;
import java.util.UUID;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;

@Component("currentUserAccess")
public class CurrentUserAccess {

    public boolean matches(Authentication authentication, UUID userId) {
        return authentication != null
                && authentication.isAuthenticated()
                && authentication.getPrincipal() instanceof AuthenticatedUser authenticatedUser
                && authenticatedUser.userId().equals(userId);
    }

    public UUID requireUserId(Authentication authentication) {
        if (authentication != null
                && authentication.isAuthenticated()
                && authentication.getPrincipal() instanceof AuthenticatedUser authenticatedUser) {
            return authenticatedUser.userId();
        }
        throw new BusinessException(ErrorCode.UNAUTHORIZED);
    }

    public AuthenticatedUser require(Authentication authentication) {
        if (authentication != null
                && authentication.isAuthenticated()
                && authentication.getPrincipal() instanceof AuthenticatedUser authenticatedUser) {
            return authenticatedUser;
        }
        throw new BusinessException(ErrorCode.UNAUTHORIZED);
    }
}
