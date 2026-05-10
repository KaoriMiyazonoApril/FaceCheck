package com.facecheck.storage;

import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
public class ObjectKeyStrategy {

    public String facePhotoKey(UUID userId, UUID photoId) {
        return "faces/user/" + userId + "/" + photoId + ".jpg";
    }

    public String checkinAttemptKey(UUID sessionId, UUID attemptId) {
        return "checkins/session/" + sessionId + "/attempt/" + attemptId + ".jpg";
    }
}
