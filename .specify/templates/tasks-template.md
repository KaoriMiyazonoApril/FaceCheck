---

description: "Task list template for feature implementation"
---

# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Core business tests are REQUIRED when the feature touches auth,
roles, person management, photo upload, external face enrollment/search/compare,
check-in, records, rate limiting, idempotency, anti-duplicate logic, or
PostgreSQL integration. Mobile tasks that involve camera, image reading, file
upload, network access, or the photo check-in flow MUST include Android emulator
or real-device validation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Backend**: `backend/src/main/java/`, `backend/src/main/resources/db/migration/`, `backend/src/test/java/`
- **Flutter app**: `app/lib/`, `app/test/`, `app/integration_test/`, `app/android/`
- Adjust path names only if the approved plan documents an equivalent
  Spring Boot monolith + Flutter app structure

<!-- 
  ============================================================================
  IMPORTANT: The tasks below are SAMPLE TASKS for illustration purposes only.
  
  The /speckit-tasks command MUST replace these with actual tasks based on:
  - User stories from spec.md (with their priorities P1, P2, P3...)
  - Feature requirements from plan.md
  - Entities from data-model.md
  - Endpoints from contracts/
  
  Tasks MUST be organized by user story so each story can be:
  - Implemented independently
  - Tested independently
  - Delivered as an MVP increment
  
  DO NOT keep these sample tasks in the generated tasks.md file.
  ============================================================================
-->

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create backend and app structure per implementation plan
- [ ] T002 Initialize Spring Boot monolith and Flutter app dependencies per constitution
- [ ] T003 [P] Configure Docker Compose, local environment configuration, Huawei Cloud FRS settings, linting, and formatting

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

Examples of foundational tasks (adjust based on your project):

- [ ] T004 Setup or update PostgreSQL schema and Flyway migrations
- [ ] T005 [P] Implement JWT authentication and authorization boundaries for user and admin flows
- [ ] T006 [P] Setup API routing, DTO validation, and unified client/service contracts
- [ ] T007 Create shared domain modules/entities for user, person, photo, face, session, check-in, record, and admin flows
- [ ] T008 [P] Configure Redis support keys and RabbitMQ queues for approved support use cases, including face enrollment and sign-in recognition workloads
- [ ] T009 Setup `FaceRecognitionProvider`, Huawei Cloud FRS client/configuration, audit logging, error handling, and environment configuration management

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - [Title] (Priority: P1) 🎯 MVP

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 1 ⚠️

> **NOTE: Write required tests FIRST, ensure they FAIL before implementation**

- [ ] T010 [P] [US1] Controller or contract test for [endpoint] in `backend/src/test/java/...`
- [ ] T011 [P] [US1] Integration test for [user journey] with PostgreSQL Testcontainers in `backend/src/test/java/...`
- [ ] T012 [P] [US1] Provider or mock-provider test for [FRS interaction] in `backend/src/test/java/...`
- [ ] T013 [P] [US1] Android emulator or real-device validation task in `app/integration_test/...` when mobile capture, upload, or check-in flow is affected

### Implementation for User Story 1

- [ ] T014 [P] [US1] Create or update domain entities in `backend/src/main/java/...`
- [ ] T015 [P] [US1] Implement app UI/state/service flow in `app/lib/...`
- [ ] T016 [US1] Implement backend service, API flow, and any provider-backed recognition path in `backend/src/main/java/...`
- [ ] T017 [US1] Add rate limiting, idempotency, duplicate prevention, upload validation, and provider-failure handling where applicable
- [ ] T018 [US1] Add logging, auditing, and error handling for user story 1 operations

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - [Title] (Priority: P2)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 2 ⚠️

- [ ] T019 [P] [US2] Controller or contract test for [endpoint] in `backend/src/test/java/...`
- [ ] T020 [P] [US2] Integration test for [user journey] with PostgreSQL Testcontainers in `backend/src/test/java/...`
- [ ] T021 [P] [US2] Provider or mock-provider test for [FRS interaction] in `backend/src/test/java/...`
- [ ] T022 [P] [US2] Android emulator or real-device validation task in `app/integration_test/...` when applicable

### Implementation for User Story 2

- [ ] T023 [P] [US2] Create or update domain entities in `backend/src/main/java/...`
- [ ] T024 [US2] Implement backend service, consumer, controller, or provider-integration flow in `backend/src/main/java/...`
- [ ] T025 [US2] Implement app feature or integration point in `app/lib/...`
- [ ] T026 [US2] Integrate with User Story 1 components while preserving role, provider, and data-boundary rules

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - [Title] (Priority: P3)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 3 ⚠️

- [ ] T027 [P] [US3] Controller or contract test for [endpoint] in `backend/src/test/java/...`
- [ ] T028 [P] [US3] Integration test for [user journey] with PostgreSQL Testcontainers in `backend/src/test/java/...`
- [ ] T029 [P] [US3] Provider or mock-provider test for [FRS interaction] in `backend/src/test/java/...`
- [ ] T030 [P] [US3] Android emulator or real-device validation task in `app/integration_test/...` when applicable

### Implementation for User Story 3

- [ ] T031 [P] [US3] Create or update domain entities in `backend/src/main/java/...`
- [ ] T032 [US3] Implement backend service, controller, or async processing flow in `backend/src/main/java/...`
- [ ] T033 [US3] Implement app feature or admin UI flow in `app/lib/...`

**Checkpoint**: All user stories should now be independently functional

---

[Add more user story phases as needed, following the same pattern]

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] TXXX [P] Documentation updates in docs/
- [ ] TXXX Code cleanup and refactoring
- [ ] TXXX Performance optimization across all stories
- [ ] TXXX [P] Additional automated tests in `backend/src/test/java/` or `app/test/`
- [ ] TXXX Security hardening
- [ ] TXXX Verify admin audit coverage and security logging
- [ ] TXXX Run Android emulator/device validation and quickstart/local environment validation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - May integrate with US1 but should be independently testable
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - May integrate with US1/US2 but should be independently testable

### Within Each User Story

- Tests (if included) MUST be written and FAIL before implementation
- Models before services
- Services before endpoints
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes, all user stories can start in parallel (if team capacity allows)
- All tests for a user story marked [P] can run in parallel
- Models within a story marked [P] can run in parallel
- Different user stories can be worked on in parallel by different team members

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Controller or contract test for [endpoint] in backend/src/test/java/..."
Task: "Integration test for [user journey] with PostgreSQL Testcontainers in backend/src/test/java/..."
Task: "Android emulator or real-device validation in app/integration_test/..."

# Launch independent implementation tasks for User Story 1 together:
Task: "Create or update domain entities in backend/src/main/java/..."
Task: "Implement app UI/state/service flow in app/lib/..."
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1
   - Developer B: User Story 2
   - Developer C: User Story 3
3. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Include auth, person, photo, face, provider abstraction, check-in, audit,
  rate-limit, idempotency, duplicate-prevention, and Android validation tasks
  whenever the feature touches them
- Direct vendor SDK calls from business modules are not allowed; model provider
  integration as explicit infrastructure tasks
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break
  independence, or implementations that bypass the monolith and data-boundary rules
