package com.facecheck.checkin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;

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
import com.jayway.jsonpath.JsonPath;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.BDDMockito;
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
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.MOCK,
        properties = "facecheck.checkin.rate-limit-max-requests=100"
)
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ConcurrentAnonymousCheckinIntegrationTest extends RedisRabbitContainerSupport {

    private static final int SAME_IDEMPOTENCY_REQUESTS = 8;
    private static final int DIFFERENT_IDEMPOTENCY_REQUESTS = 8;

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

        matchedUser = saveUser("concurrent-user");
        sessionOwner = saveUser("concurrent-session-owner");
        session = savePublishedSession("qr-concurrent", sessionOwner.getId());

        given(faceRecognitionProvider.detectFace(any()))
                .willReturn(new FaceRecognitionProvider.DetectFaceResult(1, true, null, "detect-concurrent"));
        given(faceRecognitionProvider.searchFace(any(), anyInt()))
                .willReturn(new FaceRecognitionProvider.SearchFaceResult(
                        List.of(new FaceRecognitionProvider.SearchCandidate(
                                "frs-face-concurrent",
                                96.0,
                                Map.of("userId", matchedUser.getId().toString())
                        )),
                        "search-concurrent"
                ));
        given(faceRecognitionProvider.compareFace(any(), eq("frs-face-concurrent")))
                .willReturn(new FaceRecognitionProvider.CompareFaceResult(true, 96.0, "compare-concurrent"));
    }

    @Test
    void concurrentRetriesWithSameIdempotencyKeyShouldNotCreateDuplicateAttemptsOrServerErrors() throws Exception {
        List<ResponseCapture> responses = runConcurrently(
                SAME_IDEMPOTENCY_REQUESTS,
                index -> submit("same-idempotency-key", "same-device-" + index)
        );

        assertThat(responses).allSatisfy(ResponseCapture::assertNoRequestException);
        assertThat(responses).allSatisfy(ResponseCapture::assertSuccessfulHttpStatus);
        assertThat(attendanceCheckinAttemptRepository.count()).isEqualTo(1);
        assertThat(attendanceRecordRepository.count()).isEqualTo(1);

        Set<String> attemptIds = responses.stream()
                .map(response -> response.read("$.data.attemptId", String.class))
                .collect(java.util.stream.Collectors.toSet());
        assertThat(attemptIds).hasSize(1);
    }

    @Test
    void concurrentDifferentIdempotencyKeysForSameRecognizedUserShouldCreateOneRecordOnly() throws Exception {
        CountDownLatch compareEntered = new CountDownLatch(DIFFERENT_IDEMPOTENCY_REQUESTS);
        BDDMockito.given(faceRecognitionProvider.compareFace(any(), eq("frs-face-concurrent")))
                .willAnswer(invocation -> {
                    compareEntered.countDown();
                    compareEntered.await(5, TimeUnit.SECONDS);
                    return new FaceRecognitionProvider.CompareFaceResult(true, 96.0, "compare-concurrent");
                });

        List<ResponseCapture> responses = runConcurrently(
                DIFFERENT_IDEMPOTENCY_REQUESTS,
                index -> submit("different-idempotency-key-" + index, "different-device-" + index)
        );

        assertThat(responses).allSatisfy(ResponseCapture::assertNoRequestException);
        assertThat(responses).allSatisfy(ResponseCapture::assertSuccessfulHttpStatus);
        assertThat(attendanceRecordRepository.count()).isEqualTo(1);

        List<CheckinStatus> statuses = responses.stream()
                .map(response -> CheckinStatus.valueOf(response.read("$.data.status", String.class)))
                .toList();
        assertThat(statuses).containsExactlyInAnyOrderElementsOf(
                java.util.stream.Stream.concat(
                                java.util.stream.Stream.of(CheckinStatus.SUCCESS),
                                java.util.stream.Stream.generate(() -> CheckinStatus.DUPLICATE_CHECKIN)
                                        .limit(DIFFERENT_IDEMPOTENCY_REQUESTS - 1L)
                        )
                        .toList()
        );
    }

    private List<ResponseCapture> runConcurrently(int requestCount, IndexedRequest requestFactory) throws Exception {
        ExecutorService executorService = Executors.newFixedThreadPool(requestCount);
        CountDownLatch ready = new CountDownLatch(requestCount);
        CountDownLatch start = new CountDownLatch(1);
        List<Future<ResponseCapture>> futures = new ArrayList<>();

        for (int index = 0; index < requestCount; index++) {
            int requestIndex = index;
            futures.add(executorService.submit(() -> {
                ready.countDown();
                if (!start.await(5, TimeUnit.SECONDS)) {
                    throw new IllegalStateException("Concurrent requests were not ready in time.");
                }
                try {
                    return requestFactory.submit(requestIndex).call();
                } catch (Exception exception) {
                    return ResponseCapture.fromException(exception);
                }
            }));
        }

        assertThat(ready.await(5, TimeUnit.SECONDS)).isTrue();
        start.countDown();

        List<ResponseCapture> responses = new ArrayList<>();
        for (Future<ResponseCapture> future : futures) {
            responses.add(future.get(20, TimeUnit.SECONDS));
        }
        executorService.shutdown();
        assertThat(executorService.awaitTermination(5, TimeUnit.SECONDS)).isTrue();
        return responses;
    }

    private Callable<ResponseCapture> submit(String idempotencyKey, String deviceId) {
        return () -> {
            MvcResult result = mockMvc.perform(multipart("/api/public/checkin/attempts")
                            .file(pngFile("concurrent.png"))
                            .param("qrToken", session.getQrToken())
                            .param("idempotencyKey", idempotencyKey)
                            .param("deviceId", deviceId))
                    .andReturn();
            return new ResponseCapture(
                    result.getResponse().getStatus(),
                    result.getResponse().getContentAsString(),
                    result.getResolvedException()
            );
        };
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
        attendanceSession.setName("Concurrent Roll Call");
        attendanceSession.setDescription("Concurrency scenario");
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

    @FunctionalInterface
    private interface IndexedRequest {
        Callable<ResponseCapture> submit(int index);
    }

    private record ResponseCapture(int status, String body, Exception exception) {

        static ResponseCapture fromException(Exception exception) {
            return new ResponseCapture(500, "", exception);
        }

        void assertNoRequestException() {
            assertThat(exception).isNull();
        }

        void assertSuccessfulHttpStatus() {
            assertThat(status).isBetween(200, 299);
        }

        <T> T read(String path, Class<T> type) {
            return JsonPath.parse(body).read(path, type);
        }
    }
}
