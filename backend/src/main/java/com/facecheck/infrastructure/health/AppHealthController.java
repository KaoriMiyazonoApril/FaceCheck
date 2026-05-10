package com.facecheck.infrastructure.health;

import com.facecheck.common.api.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/health")
public class AppHealthController {

    private final DependencyHealthService dependencyHealthService;

    public AppHealthController(DependencyHealthService dependencyHealthService) {
        this.dependencyHealthService = dependencyHealthService;
    }

    @GetMapping
    public ApiResponse<DependencyHealthService.HealthSnapshot> health() {
        return ApiResponse.success(dependencyHealthService.currentStatus());
    }
}
