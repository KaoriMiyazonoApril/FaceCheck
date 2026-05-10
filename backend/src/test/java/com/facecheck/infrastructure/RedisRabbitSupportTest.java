package com.facecheck.infrastructure;

import static org.assertj.core.api.Assertions.assertThat;

import com.facecheck.infrastructure.redis.RedisKeyFactory;
import com.facecheck.support.RedisRabbitContainerSupport;
import org.junit.jupiter.api.Test;
import org.springframework.amqp.core.AmqpAdmin;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@ActiveProfiles("test")
class RedisRabbitSupportTest extends RedisRabbitContainerSupport {

    @Autowired
    private StringRedisTemplate redisTemplate;

    @Autowired
    private RedisKeyFactory redisKeyFactory;

    @Autowired
    private AmqpAdmin amqpAdmin;

    @Value("${facecheck.messaging.face-photo.register-queue}")
    private String registerQueue;

    @Value("${facecheck.messaging.face-photo.register-retry-queue}")
    private String registerRetryQueue;

    @Value("${facecheck.messaging.face-photo.register-dlq-queue}")
    private String registerDlqQueue;

    @Value("${facecheck.messaging.face-photo.delete-queue}")
    private String deleteQueue;

    @Value("${facecheck.messaging.face-photo.delete-retry-queue}")
    private String deleteRetryQueue;

    @Value("${facecheck.messaging.face-photo.delete-dlq-queue}")
    private String deleteDlqQueue;

    @Test
    void shouldExposeRedisNamespacesAndRabbitTopology() {
        String blacklistKey = redisKeyFactory.authBlacklist("jti-1");
        String idempotencyKey = redisKeyFactory.checkinIdempotency("idem-1");
        String qrKey = redisKeyFactory.sessionQr("qr-1");

        redisTemplate.opsForValue().set(blacklistKey, "1");
        redisTemplate.opsForValue().set(idempotencyKey, "done");
        redisTemplate.opsForValue().set(qrKey, "session-1");

        assertThat(redisTemplate.opsForValue().get(blacklistKey)).isEqualTo("1");
        assertThat(redisTemplate.opsForValue().get(idempotencyKey)).isEqualTo("done");
        assertThat(redisTemplate.opsForValue().get(qrKey)).isEqualTo("session-1");

        assertThat(amqpAdmin.getQueueProperties(registerQueue)).isNotNull();
        assertThat(amqpAdmin.getQueueProperties(registerRetryQueue)).isNotNull();
        assertThat(amqpAdmin.getQueueProperties(registerDlqQueue)).isNotNull();
        assertThat(amqpAdmin.getQueueProperties(deleteQueue)).isNotNull();
        assertThat(amqpAdmin.getQueueProperties(deleteRetryQueue)).isNotNull();
        assertThat(amqpAdmin.getQueueProperties(deleteDlqQueue)).isNotNull();
    }
}
