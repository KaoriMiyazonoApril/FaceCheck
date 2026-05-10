package com.facecheck.admin.service;

import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class ExternalCallAuditService {

    private static final Logger log = LoggerFactory.getLogger(ExternalCallAuditService.class);

    public void recordSuccess(String serviceName, String operation, UUID relatedEntityId, String requestId, long latencyMs) {
        log.info(
                "external_call_success service={} operation={} entityId={} requestId={} latencyMs={}",
                serviceName,
                operation,
                relatedEntityId,
                requestId,
                latencyMs
        );
    }

    public void recordFailure(
            String serviceName,
            String operation,
            UUID relatedEntityId,
            String requestId,
            String resultCode,
            long latencyMs,
            Throwable exception
    ) {
        log.warn(
                "external_call_failure service={} operation={} entityId={} requestId={} resultCode={} latencyMs={}",
                serviceName,
                operation,
                relatedEntityId,
                requestId,
                resultCode,
                latencyMs,
                exception
        );
    }
}
