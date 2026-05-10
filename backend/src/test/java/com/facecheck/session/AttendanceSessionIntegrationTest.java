package com.facecheck.session;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.facecheck.auth.service.JwtService;
import com.facecheck.auth.service.PasswordService;
import com.facecheck.identity.model.User;
import com.facecheck.identity.model.UserRole;
import com.facecheck.identity.model.UserStatus;
import com.facecheck.identity.repo.UserRepository;
import com.facecheck.session.repo.AttendanceSessionRepository;
import com.facecheck.support.RedisRabbitContainerSupport;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
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
class AttendanceSessionIntegrationTest extends RedisRabbitContainerSupport {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private AttendanceSessionRepository attendanceSessionRepository;

    @Autowired
    private PasswordService passwordService;

    @Autowired
    private JwtService jwtService;

    private User adminUser;

    @BeforeEach
    void setUp() {
        attendanceSessionRepository.deleteAll();
        userRepository.deleteAll();
        adminUser = saveUser("admin-user", "password123", UserRole.ADMIN, UserStatus.ACTIVE);
    }

    @Test
    void shouldPublishResolveAndInvalidateStaleQrTokensAfterReset() throws Exception {
        Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);

        String createResponse = mockMvc.perform(post("/api/admin/sessions")
                        .header(HttpHeaders.AUTHORIZATION, bearer(adminUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name":"Morning Roll Call",
                                  "description":"Main building lobby",
                                  "startTime":"%s",
                                  "endTime":"%s"
                                }
                                """.formatted(now.minus(10, ChronoUnit.MINUTES), now.plus(30, ChronoUnit.MINUTES))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.status").value("DRAFT"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        String sessionId = com.jayway.jsonpath.JsonPath.read(createResponse, "$.data.sessionId");

        mockMvc.perform(post("/api/admin/sessions/{sessionId}/publish", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(adminUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("PUBLISHED"));

        String oldTokenResponse = mockMvc.perform(get("/api/admin/sessions/{sessionId}/qr-token", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(adminUser)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        String oldToken = com.jayway.jsonpath.JsonPath.read(oldTokenResponse, "$.data.qrToken");

        mockMvc.perform(post("/api/public/checkin/session-entry")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"qrToken":"%s"}
                                """.formatted(oldToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.canCheckin").value(true));

        String rotatedResponse = mockMvc.perform(post("/api/admin/sessions/{sessionId}/qr-token/reset", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(adminUser)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        String newToken = com.jayway.jsonpath.JsonPath.read(rotatedResponse, "$.data.qrToken");

        mockMvc.perform(post("/api/public/checkin/session-entry")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"qrToken":"%s"}
                                """.formatted(oldToken)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("INVALID_QR_TOKEN"));

        mockMvc.perform(post("/api/public/checkin/session-entry")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"qrToken":"%s"}
                                """.formatted(newToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.canCheckin").value(true));
    }

    @Test
    void shouldReturnLifecycleRefusalReasons() throws Exception {
        Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);

        String futureResponse = mockMvc.perform(post("/api/admin/sessions")
                        .header(HttpHeaders.AUTHORIZATION, bearer(adminUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name":"Future Session",
                                  "startTime":"%s",
                                  "endTime":"%s"
                                }
                                """.formatted(now.plus(20, ChronoUnit.MINUTES), now.plus(80, ChronoUnit.MINUTES))))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();

        String futureSessionId = com.jayway.jsonpath.JsonPath.read(futureResponse, "$.data.sessionId");

        mockMvc.perform(post("/api/admin/sessions/{sessionId}/publish", futureSessionId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(adminUser)))
                .andExpect(status().isOk());

        String futureTokenResponse = mockMvc.perform(get("/api/admin/sessions/{sessionId}/qr-token", futureSessionId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(adminUser)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        String futureToken = com.jayway.jsonpath.JsonPath.read(futureTokenResponse, "$.data.qrToken");

        mockMvc.perform(post("/api/public/checkin/session-entry")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"qrToken":"%s"}
                                """.formatted(futureToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.canCheckin").value(false))
                .andExpect(jsonPath("$.data.refusalCode").value("SESSION_NOT_STARTED"));

        String closableResponse = mockMvc.perform(post("/api/admin/sessions")
                        .header(HttpHeaders.AUTHORIZATION, bearer(adminUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name":"Closable Session",
                                  "startTime":"%s",
                                  "endTime":"%s"
                                }
                                """.formatted(now.minus(20, ChronoUnit.MINUTES), now.plus(20, ChronoUnit.MINUTES))))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();

        String closableSessionId = com.jayway.jsonpath.JsonPath.read(closableResponse, "$.data.sessionId");
        mockMvc.perform(post("/api/admin/sessions/{sessionId}/publish", closableSessionId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(adminUser)))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/admin/sessions/{sessionId}/close", closableSessionId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(adminUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("CLOSED"));

        String closedTokenResponse = mockMvc.perform(get("/api/admin/sessions/{sessionId}/qr-token", closableSessionId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(adminUser)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        String closedToken = com.jayway.jsonpath.JsonPath.read(closedTokenResponse, "$.data.qrToken");

        mockMvc.perform(post("/api/public/checkin/session-entry")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"qrToken":"%s"}
                                """.formatted(closedToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.canCheckin").value(false))
                .andExpect(jsonPath("$.data.refusalCode").value("SESSION_CLOSED"));
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
