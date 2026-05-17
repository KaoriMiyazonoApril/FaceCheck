package com.facecheck.identity;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.facecheck.auth.service.JwtService;
import com.facecheck.auth.service.PasswordService;
import com.facecheck.identity.model.User;
import com.facecheck.identity.model.UserRole;
import com.facecheck.identity.model.UserStatus;
import com.facecheck.identity.repo.UserRepository;
import com.facecheck.support.RedisRabbitContainerSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
@ActiveProfiles("test")
class UserManagementIntegrationTest extends RedisRabbitContainerSupport {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordService passwordService;

    @Autowired
    private JwtService jwtService;

    private User regularUser;
    private User anotherUser;
    private User adminUser;

    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
        regularUser = saveUser("regular-user", "password123", UserRole.USER, UserStatus.ACTIVE);
        anotherUser = saveUser("another-user", "password123", UserRole.USER, UserStatus.ACTIVE);
        adminUser = saveUser("admin-user", "password123", UserRole.ADMIN, UserStatus.ACTIVE);
    }

    @Test
    void shouldUpdateOwnUsernameAndPassword() throws Exception {
        String token = bearer(regularUser);

        mockMvc.perform(put("/api/me/profile")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"renamed-user","password":"updated-pass"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value("renamed-user"));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"regular-user","password":"password123"}
                                """))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"renamed-user","password":"updated-pass"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.user.username").value("renamed-user"));
    }

    @Test
    void shouldRejectDuplicateUsernameUpdates() throws Exception {
        String token = bearer(regularUser);

        mockMvc.perform(put("/api/me/profile")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"another-user"}
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("DUPLICATE_USERNAME"));
    }

    @Test
    void shouldAllowAdminCreateEditAndDisableUsers() throws Exception {
        String adminToken = bearer(adminUser);

        mockMvc.perform(get("/api/admin/users")
                        .header(HttpHeaders.AUTHORIZATION, adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[?(@.username=='regular-user')]").exists())
                .andExpect(jsonPath("$.data[?(@.username=='another-user')]").exists())
                .andExpect(jsonPath("$.data[?(@.username=='admin-user')]").exists());

        String createdUserId = mockMvc.perform(post("/api/admin/users")
                        .header(HttpHeaders.AUTHORIZATION, adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"managed-user","password":"password123","role":"USER"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value("managed-user"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        String userId = com.jayway.jsonpath.JsonPath.read(createdUserId, "$.data.userId");

        mockMvc.perform(put("/api/admin/users/{userId}", userId)
                        .header(HttpHeaders.AUTHORIZATION, adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"managed-admin","role":"ADMIN"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value("managed-admin"))
                .andExpect(jsonPath("$.data.role").value("ADMIN"));

        mockMvc.perform(post("/api/admin/users/{userId}/disable", userId)
                        .header(HttpHeaders.AUTHORIZATION, adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("DISABLED"));

        mockMvc.perform(get("/api/admin/users")
                        .header(HttpHeaders.AUTHORIZATION, adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[?(@.username=='managed-admin' && @.status=='DISABLED')]").exists());

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"managed-admin","password":"password123"}
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("ACCOUNT_DISABLED"));
    }

    private String bearer(User user) {
        return "Bearer " + jwtService.issue(user).accessToken();
    }

    private User saveUser(String username, String rawPassword, UserRole role, UserStatus status) {
        User user = new User();
        user.setUsername(username);
        user.setPasswordHash(passwordService.hash(rawPassword));
        user.setRole(role);
        user.setStatus(status);
        return userRepository.save(user);
    }
}
