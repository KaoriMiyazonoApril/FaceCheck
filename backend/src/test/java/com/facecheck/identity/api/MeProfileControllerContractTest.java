package com.facecheck.identity.api;

import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.facecheck.auth.filter.JwtAuthenticationFilter;
import com.facecheck.common.error.GlobalExceptionHandler;
import com.facecheck.identity.api.dto.UpdateProfileRequest;
import com.facecheck.identity.api.dto.UserProfileResponse;
import com.facecheck.identity.model.UserRole;
import com.facecheck.identity.model.UserStatus;
import com.facecheck.identity.service.UserProfileService;
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

@WebMvcTest(MeProfileController.class)
@AutoConfigureMockMvc(addFilters = false)
@ActiveProfiles("test")
@Import(GlobalExceptionHandler.class)
class MeProfileControllerContractTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserProfileService userProfileService;

    @MockBean
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    @Test
    void shouldExposeUsernameOnlyProfileContract() throws Exception {
        UUID userId = UUID.randomUUID();
        given(userProfileService.getCurrentProfile(null))
                .willReturn(new UserProfileResponse(userId, "profile-user", UserRole.USER, UserStatus.ACTIVE));

        mockMvc.perform(get("/api/me/profile"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.userId").value(userId.toString()))
                .andExpect(jsonPath("$.data.username").value("profile-user"))
                .andExpect(jsonPath("$.data.role").value("USER"))
                .andExpect(jsonPath("$.data.status").value("ACTIVE"))
                .andExpect(jsonPath("$.data.phone").doesNotExist())
                .andExpect(jsonPath("$.data.email").doesNotExist());
    }

    @Test
    void shouldUpdateUsernameOnlyProfileContract() throws Exception {
        UUID userId = UUID.randomUUID();
        UpdateProfileRequest request = new UpdateProfileRequest("renamed-user", "new-password");
        given(userProfileService.updateCurrentProfile(null, request))
                .willReturn(new UserProfileResponse(userId, "renamed-user", UserRole.USER, UserStatus.ACTIVE));

        mockMvc.perform(put("/api/me/profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"renamed-user","password":"new-password"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value("renamed-user"))
                .andExpect(jsonPath("$.data.phone").doesNotExist())
                .andExpect(jsonPath("$.data.email").doesNotExist());
    }
}
