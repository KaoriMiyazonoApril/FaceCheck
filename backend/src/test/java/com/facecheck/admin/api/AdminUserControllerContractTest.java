package com.facecheck.admin.api;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.facecheck.admin.service.AdminUserService;
import com.facecheck.auth.filter.JwtAuthenticationFilter;
import com.facecheck.common.error.GlobalExceptionHandler;
import com.facecheck.identity.api.dto.UserProfileResponse;
import com.facecheck.identity.model.UserRole;
import com.facecheck.identity.model.UserStatus;
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

@WebMvcTest(AdminUserController.class)
@AutoConfigureMockMvc(addFilters = false)
@ActiveProfiles("test")
@Import(GlobalExceptionHandler.class)
class AdminUserControllerContractTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private AdminUserService adminUserService;

    @MockBean
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    @Test
    void shouldListManagedUsersWithUsernameOnlyContract() throws Exception {
        UUID firstUserId = UUID.randomUUID();
        UUID secondUserId = UUID.randomUUID();
        given(adminUserService.listUsers())
                .willReturn(java.util.List.of(
                        new UserProfileResponse(firstUserId, "managed-admin", UserRole.ADMIN, UserStatus.ACTIVE),
                        new UserProfileResponse(secondUserId, "managed-user", UserRole.USER, UserStatus.DISABLED)
                ));

        mockMvc.perform(get("/api/admin/users"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].userId").value(firstUserId.toString()))
                .andExpect(jsonPath("$.data[0].username").value("managed-admin"))
                .andExpect(jsonPath("$.data[0].phone").doesNotExist())
                .andExpect(jsonPath("$.data[0].email").doesNotExist())
                .andExpect(jsonPath("$.data[1].status").value("DISABLED"));
    }

    @Test
    void shouldCreateUserWithUsernameOnlyContract() throws Exception {
        UUID userId = UUID.randomUUID();
        given(adminUserService.createUser(any()))
                .willReturn(new UserProfileResponse(userId, "managed-user", UserRole.USER, UserStatus.ACTIVE));

        mockMvc.perform(post("/api/admin/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"managed-user","password":"password123","role":"USER"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.userId").value(userId.toString()))
                .andExpect(jsonPath("$.data.username").value("managed-user"))
                .andExpect(jsonPath("$.data.phone").doesNotExist())
                .andExpect(jsonPath("$.data.email").doesNotExist());
    }

    @Test
    void shouldEditAndDisableUserLifecycleContract() throws Exception {
        UUID userId = UUID.randomUUID();
        given(adminUserService.updateUser(any(), any()))
                .willReturn(new UserProfileResponse(userId, "managed-admin", UserRole.ADMIN, UserStatus.ACTIVE));
        given(adminUserService.disableUser(userId))
                .willReturn(new UserProfileResponse(userId, "managed-admin", UserRole.ADMIN, UserStatus.DISABLED));

        mockMvc.perform(put("/api/admin/users/{userId}", userId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"managed-admin","role":"ADMIN"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value("managed-admin"))
                .andExpect(jsonPath("$.data.status").value("ACTIVE"));

        mockMvc.perform(post("/api/admin/users/{userId}/disable", userId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("DISABLED"));
    }
}
