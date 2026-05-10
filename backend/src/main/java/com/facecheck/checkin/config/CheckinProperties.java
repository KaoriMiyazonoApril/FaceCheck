package com.facecheck.checkin.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "facecheck.checkin")
public class CheckinProperties {

    private int rateLimitWindowSeconds = 60;
    private int rateLimitMaxRequests = 5;
    private int idempotencyTtlHours = 24;
    private int searchMaxCandidates = 3;
    private int nextPollAfterSeconds = 3;
    private boolean asyncEnabled = false;

    public int getRateLimitWindowSeconds() {
        return rateLimitWindowSeconds;
    }

    public void setRateLimitWindowSeconds(int rateLimitWindowSeconds) {
        this.rateLimitWindowSeconds = rateLimitWindowSeconds;
    }

    public int getRateLimitMaxRequests() {
        return rateLimitMaxRequests;
    }

    public void setRateLimitMaxRequests(int rateLimitMaxRequests) {
        this.rateLimitMaxRequests = rateLimitMaxRequests;
    }

    public int getIdempotencyTtlHours() {
        return idempotencyTtlHours;
    }

    public void setIdempotencyTtlHours(int idempotencyTtlHours) {
        this.idempotencyTtlHours = idempotencyTtlHours;
    }

    public int getSearchMaxCandidates() {
        return searchMaxCandidates;
    }

    public void setSearchMaxCandidates(int searchMaxCandidates) {
        this.searchMaxCandidates = searchMaxCandidates;
    }

    public int getNextPollAfterSeconds() {
        return nextPollAfterSeconds;
    }

    public void setNextPollAfterSeconds(int nextPollAfterSeconds) {
        this.nextPollAfterSeconds = nextPollAfterSeconds;
    }

    public boolean isAsyncEnabled() {
        return asyncEnabled;
    }

    public void setAsyncEnabled(boolean asyncEnabled) {
        this.asyncEnabled = asyncEnabled;
    }
}
