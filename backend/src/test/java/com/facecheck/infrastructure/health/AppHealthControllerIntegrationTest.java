package com.facecheck.infrastructure.health;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.mockito.BDDMockito.given;

import com.facecheck.infrastructure.logging.RequestTraceFilter;
import com.facecheck.infrastructure.security.BootstrapSecurityConfig;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(AppHealthController.class)
@Import({RequestTraceFilter.class, BootstrapSecurityConfig.class})
class AppHealthControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private DependencyHealthService dependencyHealthService;

    @BeforeEach
    void setUp() {
        given(dependencyHealthService.currentStatus()).willReturn(
                new DependencyHealthService.HealthSnapshot(
                        "UP",
                        List.of(
                                new DependencyHealthService.DependencyStatus("postgres", true, "AVAILABLE"),
                                new DependencyHealthService.DependencyStatus("redis", true, "AVAILABLE"),
                                new DependencyHealthService.DependencyStatus("rabbitmq", true, "AVAILABLE")
                        )
                )
        );
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
}
