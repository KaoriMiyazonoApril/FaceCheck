package com.facecheck.infrastructure.huawei;

import com.facecheck.infrastructure.config.HuaweiCloudProperties;
import java.util.List;
import java.util.Map;

public class HuaweiFrsClient {

    private final HuaweiCloudProperties properties;

    public HuaweiFrsClient(HuaweiCloudProperties properties) {
        this.properties = properties;
    }

    public DetectFaceResponse detect(byte[] imageBytes) {
        throw new UnsupportedOperationException("Real Huawei FRS calls are not enabled in automated tests");
    }

    public EnrollFaceResponse enroll(String externalImageId, Map<String, String> externalFields, byte[] imageBytes) {
        throw new UnsupportedOperationException("Real Huawei FRS calls are not enabled in automated tests");
    }

    public SearchFaceResponse search(byte[] imageBytes, int maxCandidates) {
        throw new UnsupportedOperationException("Real Huawei FRS calls are not enabled in automated tests");
    }

    public CompareFaceResponse compare(byte[] imageBytes, String faceId) {
        throw new UnsupportedOperationException("Real Huawei FRS calls are not enabled in automated tests");
    }

    public void delete(String faceId) {
        throw new UnsupportedOperationException("Real Huawei FRS calls are not enabled in automated tests");
    }

    public HuaweiCloudProperties properties() {
        return properties;
    }

    public record DetectFaceResponse(int faceCount, String requestId) {
    }

    public record EnrollFaceResponse(String faceId, String requestId) {
    }

    public record SearchFaceResponse(List<SearchCandidate> candidates, String requestId) {
    }

    public record SearchCandidate(String faceId, double similarity, Map<String, String> externalFields) {
    }

    public record CompareFaceResponse(double similarity, String requestId) {
    }
}
