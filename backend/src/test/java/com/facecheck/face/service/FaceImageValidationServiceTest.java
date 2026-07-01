package com.facecheck.face.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.facecheck.common.error.BusinessException;
import java.util.Base64;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

class FaceImageValidationServiceTest {

    private static final byte[] PNG_BYTES = Base64.getDecoder().decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    );

    private final FaceImageValidationService service =
            new FaceImageValidationService(new ImageHashService());

    @Test
    void rejectsWhenExtensionDoesNotMatchDetectedContent() {
        MockMultipartFile file = new MockMultipartFile(
                "file", "portrait.jpg", "image/jpeg", PNG_BYTES
        );

        assertThatThrownBy(() -> service.validate(file))
                .isInstanceOf(BusinessException.class)
                .hasMessage("Image type and extension do not match.");
    }

    @Test
    void acceptsCanonicalMetadataThatMatchesDetectedContent() {
        MockMultipartFile file = new MockMultipartFile(
                "file", "face_123.png", "image/png", PNG_BYTES
        );

        FaceImageValidationService.ValidatedImage validated = service.validate(file);

        assertThat(validated.contentType()).isEqualTo("image/png");
        assertThat(validated.extension()).isEqualTo("png");
        assertThat(validated.content()).isEqualTo(PNG_BYTES);
    }
}
