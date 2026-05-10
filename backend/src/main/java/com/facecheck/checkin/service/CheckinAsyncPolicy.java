package com.facecheck.checkin.service;

import com.facecheck.checkin.config.CheckinProperties;
import com.facecheck.session.model.AttendanceSession;
import org.springframework.stereotype.Service;

@Service
public class CheckinAsyncPolicy {

    private final CheckinProperties checkinProperties;

    public CheckinAsyncPolicy(CheckinProperties checkinProperties) {
        this.checkinProperties = checkinProperties;
    }

    public boolean shouldProcessAsync(AttendanceSession session) {
        return checkinProperties.isAsyncEnabled();
    }

    public int nextPollAfterSeconds() {
        return checkinProperties.getNextPollAfterSeconds();
    }
}
