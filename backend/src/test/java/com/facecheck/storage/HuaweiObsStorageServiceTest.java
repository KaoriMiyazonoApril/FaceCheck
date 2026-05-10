package com.facecheck.storage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.facecheck.common.error.BusinessException;
import com.facecheck.infrastructure.config.HuaweiCloudProperties;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class HuaweiObsStorageServiceTest {

    @Test
    void shouldUploadDeleteAndMintPreviewUrl() {
        HuaweiCloudProperties properties = new HuaweiCloudProperties();
        properties.setObsBucket("facecheck-bucket");
        properties.setObsRegion("cn-test-1");
        properties.setObsEndpoint("https://obs.example.com");
        ObjectKeyStrategy objectKeyStrategy = new ObjectKeyStrategy();
        HuaweiObsStorageService service = new HuaweiObsStorageServiceImpl(properties, objectKeyStrategy);

        String objectKey = objectKeyStrategy.facePhotoKey(UUID.randomUUID(), UUID.randomUUID());
        HuaweiObsStorageService.StoredObject storedObject =
                service.upload(objectKey, "face-bytes".getBytes(StandardCharsets.UTF_8), "image/jpeg");

        assertThat(storedObject.bucket()).isEqualTo("facecheck-bucket");
        assertThat(storedObject.region()).isEqualTo("cn-test-1");
        assertThat(storedObject.objectKey()).isEqualTo(objectKey);
        assertThat(storedObject.storageProvider()).isEqualTo("HUAWEI_OBS");

        URI previewUrl = service.generatePreviewUrl(objectKey);
        assertThat(previewUrl.toString()).contains("https://obs.example.com/facecheck-bucket/");
        assertThat(previewUrl.toString()).contains(objectKey);

        service.delete(objectKey);

        assertThatThrownBy(() -> service.generatePreviewUrl(objectKey))
                .isInstanceOf(BusinessException.class);
    }
}
