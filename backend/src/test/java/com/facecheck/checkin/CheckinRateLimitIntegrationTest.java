package com.facecheck.checkin;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.facecheck.checkin.repo.AttendanceCheckinAttemptRepository;
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
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestPropertySource(properties = {
        "facecheck.checkin.rate-limit-window-seconds=60",
        "facecheck.checkin.rate-limit-max-requests=2"
})
class CheckinRateLimitIntegrationTest extends RedisRabbitContainerSupport {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private AttendanceSessionRepository attendanceSessionRepository;

    @Autowired
    private AttendanceCheckinAttemptRepository attendanceCheckinAttemptRepository;

    @Autowired
    private StringRedisTemplate stringRedisTemplate;

    @MockBean
    private FaceRecognitionProvider faceRecognitionProvider;

    private User sessionOwner;
    private AttendanceSession session;

    @BeforeEach
    void setUp() {
        attendanceCheckinAttemptRepository.deleteAll();
        attendanceSessionRepository.deleteAll();
        userRepository.deleteAll();
        flushRedis();

        sessionOwner = saveUser("rate-limit-user");
        session = savePublishedSession("qr-rate-limit", sessionOwner.getId());

        given(faceRecognitionProvider.detectFace(any()))
                .willReturn(new FaceRecognitionProvider.DetectFaceResult(0, false, "NO_FACE", "detect-1"));
    }

    @Test
    void shouldThrottleRepeatedAnonymousSubmissionsBySessionAndClient() throws Exception {
        mockMvc.perform(multipart("/api/public/checkin/attempts")
                        .file(pngFile("checkin-1.png"))
                        .param("qrToken", session.getQrToken())
                        .param("idempotencyKey", "rate-1")
                        .param("deviceId", "device-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.resultCode").value("NO_FACE"));

        mockMvc.perform(multipart("/api/public/checkin/attempts")
                        .file(pngFile("checkin-2.png"))
                        .param("qrToken", session.getQrToken())
                        .param("idempotencyKey", "rate-2")
                        .param("deviceId", "device-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.resultCode").value("NO_FACE"));

        mockMvc.perform(multipart("/api/public/checkin/attempts")
                        .file(pngFile("checkin-3.png"))
                        .param("qrToken", session.getQrToken())
                        .param("idempotencyKey", "rate-3")
                        .param("deviceId", "device-1"))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.error.code").value("RATE_LIMITED"));
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
