package com.facecheck.infrastructure.health;

import java.util.List;
import javax.sql.DataSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.data.redis.connection.RedisConnection;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.stereotype.Service;

@Service
public class DependencyHealthService {

    private static final Logger log = LoggerFactory.getLogger(DependencyHealthService.class);

    private final ObjectProvider<DataSource> dataSourceProvider;
    private final ObjectProvider<RedisConnectionFactory> redisConnectionFactoryProvider;
    private final ObjectProvider<ConnectionFactory> rabbitConnectionFactoryProvider;

    public DependencyHealthService(
            ObjectProvider<DataSource> dataSourceProvider,
            ObjectProvider<RedisConnectionFactory> redisConnectionFactoryProvider,
            ObjectProvider<ConnectionFactory> rabbitConnectionFactoryProvider
    ) {
        this.dataSourceProvider = dataSourceProvider;
        this.redisConnectionFactoryProvider = redisConnectionFactoryProvider;
        this.rabbitConnectionFactoryProvider = rabbitConnectionFactoryProvider;
    }

    public HealthSnapshot currentStatus() {
        List<DependencyStatus> dependencies = List.of(
                postgresStatus(),
                redisStatus(),
                rabbitStatus()
        );

        boolean ready = dependencies.stream().allMatch(DependencyStatus::available);
        return new HealthSnapshot(ready ? "UP" : "DEGRADED", dependencies);
    }

    private DependencyStatus dependency(String name, boolean available) {
        return new DependencyStatus(name, available, available ? "AVAILABLE" : "MISSING");
    }

    private DependencyStatus postgresStatus() {
        DataSource dataSource = dataSourceProvider.getIfAvailable();
        if (dataSource == null) {
            return dependency("postgres", false);
        }

        try (java.sql.Connection connection = dataSource.getConnection()) {
            return dependency("postgres", connection.isValid(2));
        } catch (Exception exception) {
            log.debug("PostgreSQL health probe failed", exception);
            return new DependencyStatus("postgres", false, "UNAVAILABLE");
        }
    }

    private DependencyStatus redisStatus() {
        RedisConnectionFactory connectionFactory = redisConnectionFactoryProvider.getIfAvailable();
        if (connectionFactory == null) {
            return dependency("redis", false);
        }

        try (RedisConnection connection = connectionFactory.getConnection()) {
            String pong = connection.ping();
            return new DependencyStatus("redis", pong != null && !pong.isBlank(), pong != null && !pong.isBlank() ? "AVAILABLE" : "UNAVAILABLE");
        } catch (Exception exception) {
            log.debug("Redis health probe failed", exception);
            return new DependencyStatus("redis", false, "UNAVAILABLE");
        }
    }

    private DependencyStatus rabbitStatus() {
        ConnectionFactory connectionFactory = rabbitConnectionFactoryProvider.getIfAvailable();
        if (connectionFactory == null) {
            return dependency("rabbitmq", false);
        }

        org.springframework.amqp.rabbit.connection.Connection connection = null;
        try {
            connection = connectionFactory.createConnection();
            return new DependencyStatus("rabbitmq", connection.isOpen(), connection.isOpen() ? "AVAILABLE" : "UNAVAILABLE");
        } catch (Exception exception) {
            log.debug("RabbitMQ health probe failed", exception);
            return new DependencyStatus("rabbitmq", false, "UNAVAILABLE");
        } finally {
            if (connection != null) {
                connection.close();
            }
        }
    }

    public record HealthSnapshot(String status, List<DependencyStatus> dependencies) {
    }

    public record DependencyStatus(String name, boolean available, String status) {
    }
}
