# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the concrete
  project context. For this repository, plans are expected to describe a
  Spring Boot monolith backend and a Flutter mobile app, plus the approved
  infrastructure boundaries for PostgreSQL, Redis, RabbitMQ, and Huawei
  Cloud FRS.
-->

**Backend Language/Version**: [e.g., Java 17 + Spring Boot 3.x or NEEDS CLARIFICATION]  
**App Language/Version**: [e.g., Dart 3.x + Flutter stable or NEEDS CLARIFICATION]  
**Primary Dependencies**: [Spring Data JPA, PostgreSQL, Redis, RabbitMQ, JWT, Flyway, Docker Compose, Testcontainers, Huawei Cloud FRS, Huawei Cloud FRS SDK or REST client, Dio, Riverpod, go_router or NEEDS CLARIFICATION]  
**Storage**: [PostgreSQL as source of truth; Redis only for cache/rate-limit/idempotency/session-assist; RabbitMQ only for async face enrollment, peak shaving, retries, DLQ; Huawei Cloud FRS only as managed face-recognition provider, not a business source of truth]  
**Testing**: [Spring Boot unit/integration tests, PostgreSQL Testcontainers, provider/mock-provider tests, Flutter tests, Android emulator/device validation where applicable]  
**Target Platform**: [Linux/Docker backend, Android primary, Windows desktop only for early UI/state/API debugging, iOS optional with separate validation]  
**Project Type**: [Spring Boot monolith + Flutter mobile app]  
**Performance Goals**: [e.g., peak check-in throughput, queue latency, response targets or NEEDS CLARIFICATION]  
**Constraints**: [two-role system only; no microservice split; Flutter app must not call Huawei Cloud FRS directly; check-in upload may be unauthenticated but must remain rate-limited, anti-abuse, and face-verified]  
**Scale/Scope**: [e.g., active users, image volume, peak check-ins, admin workload or NEEDS CLARIFICATION]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [ ] The feature stays inside the Spring Boot monolith and does not introduce a
      new remote service split for auth, person, photo, face, check-in, or record logic.
- [ ] Backend and app technologies remain within the constitution-approved stack,
      or the plan explicitly includes the required constitution/spec/tasks amendments.
- [ ] Huawei Cloud FRS access remains behind the backend boundary; the Flutter app
      does not call FRS directly and business code depends on `FaceRecognitionProvider`
      rather than vendor-specific APIs.
- [ ] Role scope remains limited to ordinary user and admin, or the change is
      explicitly framed as a constitution amendment.
- [ ] PostgreSQL remains the sole business source of truth; Redis and RabbitMQ
      usage is limited to their approved support roles, and external face identifiers
      are treated only as references or audit data.
- [ ] If the feature touches check-in or upload flows, the plan documents JWT
      boundaries, rate limiting, anti-brush controls, idempotency, duplicate
      prevention, face-recognition validation, and external-provider failure handling.
- [ ] If the feature touches face upload or recognition flows, the plan documents
      FRS provider configuration, queue boundaries, timeout/retry behavior, and
      any manual-review path.
- [ ] If the feature touches camera, image reading, file upload, permissions,
      network access, or the photo check-in flow, the plan includes Android
      emulator or real-device validation.
- [ ] Core business changes include the required automated tests, including
      PostgreSQL Testcontainers coverage where integration behavior changes.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)
Plans SHOULD align to the backend/app split below unless the repository already
uses an equivalent structure and the plan documents the mapping.

```text
backend/
├── src/main/java/.../
│   ├── auth/
│   ├── user/
│   ├── person/
│   ├── photo/
│   ├── face/
│   ├── checkin/
│   ├── session/
│   ├── record/
│   ├── admin/
│   ├── common/
│   └── infrastructure/
├── src/main/resources/db/migration/
└── src/test/java/.../

app/
├── lib/
│   ├── features/
│   ├── router/
│   ├── services/
│   └── shared/
├── test/
├── integration_test/
├── android/
└── ios/
```

**Structure Decision**: [Document the real backend/app paths, where
`FaceRecognitionProvider` and its Huawei Cloud FRS implementation live, and
explain any deviation from the recommended module split.]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
