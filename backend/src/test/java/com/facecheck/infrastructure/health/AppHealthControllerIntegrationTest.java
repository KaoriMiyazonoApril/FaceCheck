package com.facecheck.infrastructure.health;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.facecheck.infrastructure.logging.RequestTraceFilter;
import java.util.List;
import java.util.stream.Stream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class AppHealthControllerIntegrationTest {

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        DependencyHealthService dependencyHealthService = new StubDependencyHealthService(
                new DependencyHealthService.HealthSnapshot(
                        "UP",
                        List.of(
                                new DependencyHealthService.DependencyStatus("postgres", true, "AVAILABLE"),
                                new DependencyHealthService.DependencyStatus("redis", true, "AVAILABLE"),
                                new DependencyHealthService.DependencyStatus("rabbitmq", true, "AVAILABLE")
                        )
                )
        );

        mockMvc = MockMvcBuilders.standaloneSetup(new AppHealthController(dependencyHealthService))
                .addFilters(new RequestTraceFilter())
                .build();
    }

    @Test
    void shouldGenerateTraceIdWhenMissing() throws Exception {
        mockMvc.perform(get("/api/health"))
                .andExpect(status().isOk())
                .andExpect(header().exists(RequestTraceFilter.TRACE_ID_HEADER))
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.status").value("UP"))
                .andExpect(jsonPath("$.data.dependencies[0].name").value("postgres"))
                .andExpect(jsonPath("$.traceId").isNotEmpty());
    }

    @Test
    void shouldReuseSuppliedTraceId() throws Exception {
        mockMvc.perform(get("/api/health").header(RequestTraceFilter.TRACE_ID_HEADER, "trace-123"))
                .andExpect(status().isOk())
                .andExpect(header().string(RequestTraceFilter.TRACE_ID_HEADER, "trace-123"))
                .andExpect(jsonPath("$.traceId").value("trace-123"));
    }

    private static final class StubDependencyHealthService extends DependencyHealthService {

        private final HealthSnapshot snapshot;

        private StubDependencyHealthService(HealthSnapshot snapshot) {
            super(emptyProvider(), emptyProvider(), emptyProvider());
            this.snapshot = snapshot;
        }

        @Override
        public HealthSnapshot currentStatus() {
            return snapshot;
        }

        private static <T> ObjectProvider<T> emptyProvider() {
            return new ObjectProvider<>() {
                @Override
                public T getObject(Object... args) {
                    return null;
                }

                @Override
                public T getIfAvailable() {
                    return null;
                }

                @Override
                public T getIfUnique() {
                    return null;
                }

                @Override
                public T getObject() {
                    return null;
                }

                @Override
                public Stream<T> stream() {
                    return Stream.empty();
                }
            };
        }
    }
}
