package com.facecheck.checkin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.facecheck.checkin.model.AttendanceCheckinAttempt;
import com.facecheck.checkin.model.AttendanceRecord;
import com.facecheck.checkin.repo.AttendanceCheckinAttemptRepository;
import com.facecheck.checkin.repo.AttendanceRecordRepository;
import com.facecheck.face.FaceRecognitionProvider;
import com.facecheck.identity.model.User;
import com.facecheck.identity.model.UserRole;
import com.facecheck.identity.model.UserStatus;
import com.facecheck.identity.repo.UserRepository;
import com.facecheck.session.model.AttendanceSession;
import com.facecheck.session.model.AttendanceSessionStatus;
import com.facecheck.session.repo.AttendanceSessionRepository;
import com.facecheck.support.RedisRabbitContainerSupport;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.redis.connection.RedisConnection;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AnonymousCheckinSuccessIntegrationTest extends RedisRabbitContainerSupport {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private AttendanceSessionRepository attendanceSessionRepository;

    @Autowired
    private AttendanceCheckinAttemptRepository attendanceCheckinAttemptRepository;

    @Autowired
    private AttendanceRecordRepository attendanceRecordRepository;

    @Autowired
    private StringRedisTemplate stringRedisTemplate;

    @MockBean
    private FaceRecognitionProvider faceRecognitionProvider;

    private User matchedUser;
    private User sessionOwner;
    private AttendanceSession session;

    @BeforeEach
    void setUp() {
        attendanceRecordRepository.deleteAll();
        attendanceCheckinAttemptRepository.deleteAll();
        attendanceSessionRepository.deleteAll();
        userRepository.deleteAll();
        flushRedis();

        matchedUser = saveUser("matched-user");
        sessionOwner = saveUser("session-owner");
        session = savePublishedSession("qr-success", sessionOwner.getId());
    }

    @Test
    void shouldCreateOneAttendanceRecordForSuccessfulAnonymousCheckin() throws Exception {
        given(faceRecognitionProvider.detectFace(any()))
                .willReturn(new FaceRecognitionProvider.DetectFaceResult(1, true, null, "detect-1"));
        given(faceRecognitionProvider.searchFace(any(), anyInt()))
                .willReturn(new FaceRecognitionProvider.SearchFaceResult(
                        List.of(new FaceRecognitionProvider.SearchCandidate(
                                "frs-face-1",
                                94.0,
                                Map.of("userId", matchedUser.getId().toString())
                        )),
                        "search-1"
                ));
        given(faceRecognitionProvider.compareFace(any(), eq("frs-face-1")))
                .willReturn(new FaceRecognitionProvider.CompareFaceResult(true, 94.0, "compare-1"));

        String response = mockMvc.perform(multipart("/api/public/checkin/attempts")
                        .file(pngFile("success.png"))
                        .param("qrToken", session.getQrToken())
                        .param("idempotencyKey", "idem-success")
                        .param("deviceId", "pixel-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.sessionId").value(session.getId().toString()))
                .andExpect(jsonPath("$.data.sessionName").value(session.getName()))
                .andExpect(jsonPath("$.data.status").value("SUCCESS"))
                .andExpect(jsonPath("$.data.resultCode").value("SUCCESS"))
                .andExpect(jsonPath("$.data.maskedUsername").isString())
                .andExpect(jsonPath("$.data.similarity").doesNotExist())
                .andReturn()
                .getResponse()
                .getContentAsString();

        UUID attemptId = UUID.fromString(com.jayway.jsonpath.JsonPath.read(response, "$.data.attemptId"));

        mockMvc.perform(get("/api/public/checkin/attempts/{attemptId}", attemptId)
                        .param("qrToken", session.getQrToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.attemptId").value(attemptId.toString()))
                .andExpect(jsonPath("$.data.status").value("SUCCESS"))
                .andExpect(jsonPath("$.data.resultCode").value("SUCCESS"))
                .andExpect(jsonPath("$.data.similarity").doesNotExist());

        AttendanceCheckinAttempt attempt = attendanceCheckinAttemptRepository.findById(attemptId).orElseThrow();
        AttendanceRecord record = attendanceRecordRepository.findAll().getFirst();

        assertThat(attempt.getStatus().name()).isEqualTo("SUCCESS");
        assertThat(attempt.getMatchedUserId()).isEqualTo(matchedUser.getId());
        assertThat(attempt.getResultCode()).isEqualTo("SUCCESS");
        assertThat(attempt.getFrsRequestId()).isEqualTo("compare-1");
        assertThat(record.getSessionId()).isEqualTo(session.getId());
        assertThat(record.getUserId()).isEqualTo(matchedUser.getId());
        assertThat(attendanceRecordRepository.count()).isEqualTo(1);
    }

    @Test
    void shouldRejectAttemptQueryWhenQrTokenBelongsToAnotherSession() throws Exception {
        given(faceRecognitionProvider.detectFace(any()))
                .willReturn(new FaceRecognitionProvider.DetectFaceResult(1, true, null, "detect-1"));
        given(faceRecognitionProvider.searchFace(any(), anyInt()))
                .willReturn(new FaceRecognitionProvider.SearchFaceResult(
                        List.of(new FaceRecognitionProvider.SearchCandidate(
                                "frs-face-1",
                                94.0,
                                Map.of("userId", matchedUser.getId().toString())
                        )),
                        "search-1"
                ));
        given(faceRecognitionProvider.compareFace(any(), eq("frs-face-1")))
                .willReturn(new FaceRecognitionProvider.CompareFaceResult(true, 94.0, "compare-1"));

        String response = mockMvc.perform(multipart("/api/public/checkin/attempts")
                        .file(pngFile("success.png"))
                        .param("qrToken", session.getQrToken())
                        .param("idempotencyKey", "idem-success")
                        .param("deviceId", "pixel-1"))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        UUID attemptId = UUID.fromString(com.jayway.jsonpath.JsonPath.read(response, "$.data.attemptId"));

        AttendanceSession otherSession = savePublishedSession("qr-other", sessionOwner.getId());

        mockMvc.perform(get("/api/public/checkin/attempts/{attemptId}", attemptId)
                        .param("qrToken", otherSession.getQrToken()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));
    }

    private User saveUser(String username) {
        User user = new User();
        user.setUsername(username);
        user.setPasswordHash("hashed-password");
        user.setRole(UserRole.USER);
        user.setStatus(UserStatus.ACTIVE);
        return userRepository.save(user);
    }

    private AttendanceSession savePublishedSession(String qrToken, UUID createdByUserId) {
        Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        AttendanceSession attendanceSession = new AttendanceSession();
        attendanceSession.setName("Morning Roll Call");
        attendanceSession.setDescription("Main building lobby");
        attendanceSession.setStartTime(now.minus(30, ChronoUnit.MINUTES));
        attendanceSession.setEndTime(now.plus(30, ChronoUnit.MINUTES));
        attendanceSession.setStatus(AttendanceSessionStatus.PUBLISHED);
        attendanceSession.setQrToken(qrToken);
        attendanceSession.setQrTokenVersion(1);
        attendanceSession.setCreatedByUserId(createdByUserId);
        return attendanceSessionRepository.save(attendanceSession);
    }

    private MockMultipartFile pngFile(String name) throws Exception {
        BufferedImage image = new BufferedImage(1, 1, BufferedImage.TYPE_INT_RGB);
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        ImageIO.write(image, "png", outputStream);
        return new MockMultipartFile("file", name, MediaType.IMAGE_PNG_VALUE, outputStream.toByteArray());
    }

    private void flushRedis() {
        RedisConnection connection = stringRedisTemplate.getConnectionFactory().getConnection();
        try {
            connection.serverCommands().flushAll();
        } finally {
            connection.close();
        }
    }
}
