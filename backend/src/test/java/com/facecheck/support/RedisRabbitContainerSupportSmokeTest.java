package com.facecheck.support;

import static org.assertj.core.api.Assertions.assertThat;

import javax.sql.DataSource;
import org.junit.jupiter.api.Test;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.connection.RedisConnection;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@ActiveProfiles("test")
class RedisRabbitContainerSupportSmokeTest extends RedisRabbitContainerSupport {

    @Autowired
    private DataSource dataSource;

    @Autowired
    private RedisConnectionFactory redisConnectionFactory;

    @Autowired
    private ConnectionFactory rabbitConnectionFactory;

    @Test
    void shouldConnectToContainerizedDependencies() throws Exception {
        try (java.sql.Connection sqlConnection = dataSource.getConnection()) {
            assertThat(sqlConnection.isValid(2)).isTrue();
        }

        try (RedisConnection redisConnection = redisConnectionFactory.getConnection()) {
            assertThat(redisConnection.ping()).isEqualTo("PONG");
        }

        org.springframework.amqp.rabbit.connection.Connection rabbitConnection =
                rabbitConnectionFactory.createConnection();
        try {
            assertThat(rabbitConnection.isOpen()).isTrue();
        } finally {
            rabbitConnection.close();
        }
    }
}
