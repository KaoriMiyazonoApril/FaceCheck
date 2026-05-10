package com.facecheck.checkin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.facecheck.checkin.model.AttendanceCheckinAttempt;
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
class AnonymousCheckinFailureIntegrationTest extends RedisRabbitContainerSupport {

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
        session = savePublishedSession("qr-failure", sessionOwner.getId());
    }

    @Test
    void shouldReturnNoFaceFailureWithoutCreatingRecords() throws Exception {
        given(faceRecognitionProvider.detectFace(any()))
                .willReturn(new FaceRecognitionProvider.DetectFaceResult(0, false, "NO_FACE", "detect-1"));

        mockMvc.perform(multipart("/api/public/checkin/attempts")
                        .file(pngFile("no-face.png"))
                        .param("qrToken", session.getQrToken())
                        .param("idempotencyKey", "idem-no-face")
                        .param("deviceId", "pixel-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("FAILED"))
                .andExpect(jsonPath("$.data.resultCode").value("NO_FACE"));

        assertThat(attendanceRecordRepository.count()).isZero();
        AttendanceCheckinAttempt attempt = attendanceCheckinAttemptRepository.findAll().getFirst();
        assertThat(attempt.getResultCode()).isEqualTo("NO_FACE");
    }

    @Test
    void shouldReturnLowConfidenceFailureWhenCompareFallsBelowThreshold() throws Exception {
        given(faceRecognitionProvider.detectFace(any()))
                .willReturn(new FaceRecognitionProvider.DetectFaceResult(1, true, null, "detect-1"));
        given(faceRecognitionProvider.searchFace(any(), anyInt()))
                .willReturn(new FaceRecognitionProvider.SearchFaceResult(
                        List.of(new FaceRecognitionProvider.SearchCandidate(
                                "frs-face-1",
                                82.0,
                                Map.of("userId", matchedUser.getId().toString())
                        )),
                        "search-1"
                ));
        given(faceRecognitionProvider.compareFace(any(), eq("frs-face-1")))
                .willReturn(new FaceRecognitionProvider.CompareFaceResult(true, 60.0, "compare-1"));

        mockMvc.perform(multipart("/api/public/checkin/attempts")
                        .file(pngFile("low-confidence.png"))
                        .param("qrToken", session.getQrToken())
                        .param("idempotencyKey", "idem-low-confidence")
                        .param("deviceId", "pixel-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("FAILED"))
                .andExpect(jsonPath("$.data.resultCode").value("LOW_CONFIDENCE"));

        assertThat(attendanceRecordRepository.count()).isZero();
    }

    @Test
    void shouldReplayIdempotentResultsWithoutReRunningRecognition() throws Exception {
        mockSuccessRecognition();

        String firstResponse = mockMvc.perform(multipart("/api/public/checkin/attempts")
                        .file(pngFile("idem.png"))
                        .param("qrToken", session.getQrToken())
                        .param("idempotencyKey", "idem-replay")
                        .param("deviceId", "pixel-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("SUCCESS"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        String secondResponse = mockMvc.perform(multipart("/api/public/checkin/attempts")
                        .file(pngFile("idem.png"))
                        .param("qrToken", session.getQrToken())
                        .param("idempotencyKey", "idem-replay")
                        .param("deviceId", "pixel-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("SUCCESS"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        String firstAttemptId = com.jayway.jsonpath.JsonPath.read(firstResponse, "$.data.attemptId");
        String secondAttemptId = com.jayway.jsonpath.JsonPath.read(secondResponse, "$.data.attemptId");

        assertThat(firstAttemptId).isEqualTo(secondAttemptId);
        assertThat(attendanceRecordRepository.count()).isEqualTo(1);
        verify(faceRecognitionProvider, times(1)).detectFace(any());
        verify(faceRecognitionProvider, times(1)).searchFace(any(), anyInt());
        verify(faceRecognitionProvider, times(1)).compareFace(any(), eq("frs-face-1"));
    }

    @Test
    void shouldNotReplayCachedResultAcrossDifferentSessions() throws Exception {
        AttendanceSession secondSession = savePublishedSession("qr-failure-2", sessionOwner.getId());
        mockSuccessRecognition();

        String firstResponse = mockMvc.perform(multipart("/api/public/checkin/attempts")
                        .file(pngFile("session-a.png"))
                        .param("qrToken", session.getQrToken())
                        .param("idempotencyKey", "shared-idem")
                        .param("deviceId", "pixel-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("SUCCESS"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        String secondResponse = mockMvc.perform(multipart("/api/public/checkin/attempts")
                        .file(pngFile("session-b.png"))
                        .param("qrToken", secondSession.getQrToken())
                        .param("idempotencyKey", "shared-idem")
                        .param("deviceId", "pixel-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("SUCCESS"))
                .andExpect(jsonPath("$.data.sessionId").value(secondSession.getId().toString()))
                .andReturn()
                .getResponse()
                .getContentAsString();

        String firstAttemptId = com.jayway.jsonpath.JsonPath.read(firstResponse, "$.data.attemptId");
        String secondAttemptId = com.jayway.jsonpath.JsonPath.read(secondResponse, "$.data.attemptId");

        assertThat(firstAttemptId).isNotEqualTo(secondAttemptId);
        assertThat(attendanceRecordRepository.count()).isEqualTo(2);
        verify(faceRecognitionProvider, times(2)).detectFace(any());
        verify(faceRecognitionProvider, times(2)).searchFace(any(), anyInt());
        verify(faceRecognitionProvider, times(2)).compareFace(any(), eq("frs-face-1"));
    }

    @Test
    void shouldTranslateRepeatedSuccessfulRecognitionIntoDuplicateCheckin() throws Exception {
        mockSuccessRecognition();

        mockMvc.perform(multipart("/api/public/checkin/attempts")
                        .file(pngFile("success-1.png"))
                        .param("qrToken", session.getQrToken())
                        .param("idempotencyKey", "idem-1")
                        .param("deviceId", "pixel-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("SUCCESS"));

        mockMvc.perform(multipart("/api/public/checkin/attempts")
                        .file(pngFile("success-2.png"))
                        .param("qrToken", session.getQrToken())
                        .param("idempotencyKey", "idem-2")
                        .param("deviceId", "pixel-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("DUPLICATE_CHECKIN"))
                .andExpect(jsonPath("$.data.resultCode").value("DUPLICATE_CHECKIN"));

        assertThat(attendanceRecordRepository.count()).isEqualTo(1);
    }

    private void mockSuccessRecognition() {
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
