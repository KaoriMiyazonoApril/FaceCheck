package com.facecheck.checkin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.facecheck.checkin.model.AttendanceRecord;
import com.facecheck.checkin.model.AttendanceRecordSource;
import com.facecheck.checkin.model.AttendanceRecordStatus;
import com.facecheck.checkin.model.AttendanceCheckinAttempt;
import com.facecheck.checkin.model.CheckinStatus;
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
class AttendanceRecordUniquenessTest extends RedisRabbitContainerSupport {

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

        matchedUser = saveUser("duplicate-user");
        sessionOwner = saveUser("session-owner");
        session = savePublishedSession("qr-uniqueness", sessionOwner.getId());

        UUID priorAttemptId = UUID.randomUUID();

        AttendanceCheckinAttempt priorAttempt = new AttendanceCheckinAttempt();
        priorAttempt.setId(priorAttemptId);
        priorAttempt.setSessionId(session.getId());
        priorAttempt.setObsBucket("facecheck-test");
        priorAttempt.setObsRegion("test-region");
        priorAttempt.setObsObjectKey("checkins/session/" + session.getId() + "/attempt/" + priorAttemptId + ".jpg");
        priorAttempt.setContentType("image/png");
        priorAttempt.setSizeBytes(12L);
        priorAttempt.setSha256("existing-attempt");
        priorAttempt.setStorageProvider("HUAWEI_OBS");
        priorAttempt.setStatus(CheckinStatus.SUCCESS);
        priorAttempt.setResultCode("SUCCESS");
        priorAttempt.setMatchedUserId(matchedUser.getId());
        priorAttempt.setMatchedFaceId("existing-face");
        priorAttempt.setSimilarity(95.0);
        priorAttempt.setIdempotencyKey("existing-idem");
        attendanceCheckinAttemptRepository.save(priorAttempt);

        AttendanceRecord record = new AttendanceRecord();
        record.setSessionId(session.getId());
        record.setUserId(matchedUser.getId());
        record.setAttemptId(priorAttemptId);
        record.setCheckinTime(Instant.now());
        record.setStatus(AttendanceRecordStatus.VALID);
        record.setSimilarity(95.0);
        record.setSource(AttendanceRecordSource.APP_QR_ANON);
        attendanceRecordRepository.save(record);

        given(faceRecognitionProvider.detectFace(any()))
                .willReturn(new FaceRecognitionProvider.DetectFaceResult(1, true, null, "detect-1"));
        given(faceRecognitionProvider.searchFace(any(), anyInt()))
                .willReturn(new FaceRecognitionProvider.SearchFaceResult(
                        List.of(new FaceRecognitionProvider.SearchCandidate(
                                "frs-face-1",
                                95.0,
                                Map.of("userId", matchedUser.getId().toString())
                        )),
                        "search-1"
                ));
        given(faceRecognitionProvider.compareFace(any(), eq("frs-face-1")))
                .willReturn(new FaceRecognitionProvider.CompareFaceResult(true, 95.0, "compare-1"));
    }

    @Test
    void shouldTranslateDatabaseUniqueConstraintIntoDuplicateCheckin() throws Exception {
        mockMvc.perform(multipart("/api/public/checkin/attempts")
                        .file(pngFile("duplicate.png"))
                        .param("qrToken", session.getQrToken())
                        .param("idempotencyKey", "idem-duplicate")
                        .param("deviceId", "pixel-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("DUPLICATE_CHECKIN"))
                .andExpect(jsonPath("$.data.resultCode").value("DUPLICATE_CHECKIN"));

        assertThat(attendanceRecordRepository.count()).isEqualTo(1);
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
