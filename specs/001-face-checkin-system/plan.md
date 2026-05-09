# Implementation Plan: 管理员场次人脸签到系统

**Branch**: `001-face-checkin-system` | **Date**: 2026-05-09 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/001-face-checkin-system/spec.md`

## Summary

实现一套以 Spring Boot 单体为中心的人脸签到系统：普通用户登录后维护用户名、密码和人脸照片库，
管理员新增、编辑、停用用户并创建签到场次与二维码，用户通过 Flutter App 扫码后可在不登录的情况下拍照签到。
后端统一封装华为云 FRS 完成人脸检测、人脸库注册、人脸搜索和候选比对确认，统一封装华为云
OBS 持久化人脸照片与签到照片；PostgreSQL 仍然是唯一业务事实源，Redis 只承担限流、
幂等、缓存和 Token 黑名单职责，RabbitMQ 负责照片注册异步化、失败重试和死信处理；
签到第一阶段保持同步识别主链路，但预留 `PROCESSING` 和后续队列削峰扩展位；系统使用唯一用户名区分用户，
不使用邮箱、手机号等外部标识作为主识别字段。

## Technical Context

**Backend Language/Version**: Java 21 LTS + Spring Boot 3.x  
**App Language/Version**: Dart 3.x + Flutter stable  
**Primary Dependencies**: Spring Web, Spring Security, Spring Data JPA, Spring Validation, PostgreSQL, Spring Data Redis, Spring AMQP, JWT, Flyway, Docker Compose, Testcontainers, Huawei Cloud FRS via `HuaweiFrsClient`, Huawei OBS SDK/service wrapper, Dio, Riverpod, go_router, camera, mobile_scanner, flutter_secure_storage  
**Storage**: PostgreSQL as the only business source of truth; Huawei Cloud FRS only as managed face-recognition capability and search index; Huawei Cloud OBS only as image object storage; Redis only for cache/rate-limit/idempotency/token-blacklist/QR parsing; RabbitMQ only for approved async workflows  
**Testing**: Spring Boot unit/integration tests, PostgreSQL/Redis/RabbitMQ Testcontainers, MockFaceRecognitionProvider tests, WireMock-style FRS client tests, OBS adapter tests with mock/test profile, Flutter widget/state/API tests, Android emulator or real-device validation for camera/scan/upload flows  
**Target Platform**: Linux/Docker backend runtime, Android as the primary mobile target, Windows desktop only for early UI/state/API debugging, iOS deferred  
**Project Type**: Spring Boot monolith + Flutter mobile app  
**Performance Goals**: P95 face-photo upload API response under 3 seconds before async registration; P95 synchronous check-in result under 10 seconds when FRS is healthy; async or degraded-path check-in result finalized within 60 seconds; photo registration finalized within 120 seconds  
**Constraints**: two-role system only; no microservice split; no local OpenCV/ONNX or self-built remote recognition service in Phase 1; Flutter app must only call Spring Boot backend APIs and must not directly access PostgreSQL, Redis, RabbitMQ, Huawei Cloud FRS, Huawei Cloud OBS, or the server filesystem; all image uploads must pass through backend validation and persistence rules  
**Scale/Scope**: course-project scope targeting up to 10,000 users, up to 50,000 face photos, up to 200 concurrent check-in submissions during a hot session, and tens of admin operators

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] The feature stays inside the Spring Boot monolith and does not introduce a
      new remote service split for auth, identity, photo, face, check-in, or record logic.
- [x] Backend and app technologies remain within the constitution-approved stack,
      including Huawei Cloud FRS and Huawei Cloud OBS.
- [x] Huawei Cloud FRS and OBS access remain behind the backend boundary; the
      Flutter app only calls Spring Boot APIs and business code depends on
      `FaceRecognitionProvider` rather than vendor-specific APIs.
- [x] Role scope remains limited to ordinary user and admin.
- [x] PostgreSQL remains the sole business source of truth; Redis and RabbitMQ
      usage is limited to approved support roles, and external face identifiers
      are treated only as references or audit data.
- [x] The plan documents JWT boundaries, rate limiting, anti-brush controls,
      idempotency, duplicate prevention, face-recognition validation, and
      external-provider failure handling for upload and check-in flows.
- [x] The plan documents FRS provider configuration, OBS configuration, queue
      boundaries, timeout/retry behavior, and a manual-review path.
- [x] The plan includes Android emulator or real-device validation for camera,
      image reading, file upload, QR scan, network access, secure storage, and
      unauthenticated photo check-in flows.
- [x] Core business changes include required automated tests with PostgreSQL
      Testcontainers coverage and containerized Redis/RabbitMQ validation.

## Project Structure

### Documentation (this feature)

```text
specs/001-face-checkin-system/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── openapi.yaml
└── tasks.md
```

### Source Code (repository root)

```text
backend/
├── src/main/java/.../
│   ├── auth/
│   ├── identity/
│   ├── face/
│   ├── storage/
│   ├── session/
│   ├── checkin/
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

**Structure Decision**: 采用用户要求的精简模块映射。`identity` 统一吸收普通用户账号、管理员账号、
个人资料和管理员用户管理逻辑，不再引入独立 `person` 模型；`checkin` 内部同时承载 `AttendanceCheckinAttempt`、
`AttendanceRecord` 和查询逻辑，不再单拆 `record` 模块；`FaceRecognitionProvider`
与 `HuaweiCloudFrsFaceRecognitionProvider` 放在 `face` 模块，`HuaweiFrsClient`
与华为云鉴权配置放在 `infrastructure` 模块；`HuaweiObsStorageService` 放在
`storage` 模块并由 `face` 与 `checkin` 复用。

## Phase 0 Research Summary

- 生产环境的人脸识别固定通过 `FaceRecognitionProvider -> HuaweiCloudFrsFaceRecognitionProvider -> HuaweiFrsClient`
  链路完成；`MockFaceRecognitionProvider` 用于本地与自动化测试。
- 第一版签到识别固定为“detect -> search -> compare”；不引入活体检测作为签到放行前提。
- 生产环境图片持久化固定通过 `HuaweiObsStorageService` 写入 OBS，后端只保存元数据，
  不向 Flutter App 下发云凭证。
- Flutter App 只访问 Spring Boot 后端，不直连 PostgreSQL、Redis、RabbitMQ、
  OBS、FRS 或服务器文件系统。
- 人脸照片注册走异步 RabbitMQ 任务；签到第一阶段同步调用 FRS，但使用统一的 attempt
  状态机预留 `PROCESSING` 和未来队列削峰扩展。
- 重复签到由 PostgreSQL 唯一约束 `unique(session_id, user_id)` 兜底，Redis 只做
  前置限流与幂等。
- 用户唯一由 `username` 区分；登录、管理和识别结果落库都围绕同一个 `User` 主体展开。
- 手动复核只处理“不确定结果”而非明显坏图或明显越权请求。

## Phase 1 Design

### Architecture Overview

Spring Boot 单体是所有业务规则、权限控制、签到规则、幂等、防重复、审计和数据一致性的
中心。华为云 FRS 仅提供人脸检测、人脸入库、人脸搜索、人脸比对和 face set 索引能力；
华为云 OBS 仅提供图片对象存储；PostgreSQL 持久化全部核心业务数据与外部引用；
Redis/RabbitMQ 只承担支撑性职责。

```text
Flutter App
  -> Spring Boot Monolith
       -> auth / identity / session / checkin / admin services
       -> face module via FaceRecognitionProvider
            -> HuaweiCloudFrsFaceRecognitionProvider
                 -> HuaweiFrsClient
                      -> Huawei Cloud FRS
       -> storage module via HuaweiObsStorageService
            -> Huawei Cloud OBS
       -> PostgreSQL (source of truth)
       -> Redis (rate limit, idempotency, blacklist, qr cache)
       -> RabbitMQ (photo registration async, retries, DLQ, future check-in peak shaving)
```

不设计本地 OpenCV、ONNX 或独立远程自建人脸识别服务；Flutter App 不在端上做最终识别判定。

### Backend Module Responsibilities

| Module | Responsibility |
|---|---|
| `auth` | 统一登录、JWT 签发与校验、角色 claims、注销与 Token 黑名单 |
| `identity` | 普通用户账号、管理员账号、用户名唯一性、个人资料维护、管理员用户生命周期管理 |
| `face` | 人脸照片元数据、照片状态机、FaceRecognitionProvider 抽象、FRS 注册/搜索/删除、人脸引用同步 |
| `storage` | OBS 上传、删除、临时 URL、对象路径规则、内容哈希与元数据封装 |
| `session` | 签到场次创建/编辑/发布/关闭/取消、二维码 token 生成和轮换、时间窗口规则 |
| `checkin` | 扫码解析、免登录签到、限流、幂等、防重复签到、attempt、record、结果查询 |
| `admin` | 管理员入口、异常处理、审计日志查询与操作；系统状态与系统配置作为第二阶段扩展 |
| `common` | 通用响应模型、DTO、错误码、异常、枚举、时间与 ID 工具 |
| `infrastructure` | Redis、RabbitMQ、Flyway、FRS/OBS 客户端配置、健康检查、结构化日志 |

### Core Services and Adapters

| Component | Role |
|---|---|
| `AuthService` | 统一认证入口、JWT 签发、注销和黑名单写入 |
| `IdentityService` | 用户账户检索、用户名唯一性校验、登录身份边界校验 |
| `UserProfileService` | 个人用户名/密码维护与个人资料读写 |
| `AdminUserService` | 管理员新增、编辑、停用用户 |
| `FacePhotoService` | 人脸照片上传校验、元数据写入、删除禁用、任务投递、状态查询 |
| `HuaweiFrsClient` | FRS REST 调用、AK/SK 签名、超时/重试、响应解析、requestId 提取 |
| `HuaweiCloudFrsFaceRecognitionProvider` | 领域级 detect/enroll/search/compare/delete 映射 |
| `HuaweiFaceSetSyncService` | FacePhoto 与 HuaweiFaceRef 状态补偿、删除重试、face set 一致性巡检 |
| `HuaweiObsStorageService` | OBS 对象上传、删除、临时 URL、对象键封装 |
| `AttendanceSessionService` | 场次生命周期、二维码 token 生成/轮换、扫码场次解析 |
| `CheckinService` | 免登录签到主编排、FRS 调用、重复判断、主状态和结果码返回 |
| `CheckinAttemptService` | Attempt 创建、状态更新、结果查询、幂等结果回放 |
| `AttendanceRecordService` | 有效签到记录写入、唯一约束冲突处理、个人/全局记录查询 |
| `AuditLogService` | 管理员关键操作审计、外部调用追踪聚合 |
| `SystemConfigService` | face set 名称、相似度阈值、照片上限、限流与幂等配置读取 |

### Domain and State Design

- `User`
  - 采用固定角色枚举 `USER`、`ADMIN`，不引入第三类角色。
  - `username` 是唯一业务标识和唯一登录名，不使用邮箱或手机号作为主识别字段。
  - 内部仍可使用 `userId` 作为数据库主键和关联键，但不得把它替代为面对用户的登录标识。
  - 管理员通过同一 `User` 模型承载，仅依靠角色与状态区分权限。
- `FacePhoto`
  - 保存 OBS 元数据、检测状态、注册状态、失败原因、启用状态。
  - 典型状态：
    - `detectStatus`: `PENDING`, `PASSED`, `FAILED`
    - `registerStatus`: `PENDING`, `ACTIVE`, `FAILED`, `DISABLED`, `DELETE_PENDING`, `DELETE_FAILED`, `DELETED`
- `HuaweiFaceRef`
  - 保存 `faceSetName`、`frsFaceId`、`externalImageId`、`externalFields`、同步状态。
  - 用于把 FRS 候选结果映射回本地 `userId`，而不是把 FRS 当事实源。
- `AttendanceSession`
  - 保存 `name`、`description`、`startTime`、`endTime`、`lateAfterTime`、`status`、
    `qrToken`、`createdBy`、审计时间。
  - `lateAfterTime` 第一阶段可为空，仅作为未来迟到分类扩展位；当前签到资格仅由
    `startTime` 和 `endTime` 决定。
- `AttendanceCheckinAttempt`
  - 先天是“尝试与结果容器”，无论成功、失败、重复或需人工复核都保留。
  - 主状态固定为：`PROCESSING`, `SUCCESS`, `FAILED`, `DUPLICATE_CHECKIN`
  - 结果码至少包括：`INVALID_QR_TOKEN`, `SESSION_NOT_STARTED`, `EXPIRED_SESSION`,
    `SESSION_CLOSED`, `SESSION_CANCELED`, `RATE_LIMITED`, `INVALID_IMAGE`, `NO_FACE`,
    `MULTIPLE_FACES`, `LOW_CONFIDENCE`, `NO_MATCH`, `FRS_TIMEOUT`,
    `FRS_RATE_LIMITED`, `FRS_ERROR`, `MANUAL_REVIEW`
- `AttendanceRecord`
  - 只表示有效签到结果，强制唯一约束 `(session_id, user_id)`。
  - 保留 `attemptId`、`similarity`、`source` 便于追溯。
- `SystemConfig`
  - 统一存 `face_set_name`、`similarity_threshold`、`max_face_photo_count`、
    `idempotency_ttl_hours`、`rate_limit_window_seconds`、`rate_limit_max_requests` 等。

### Persistence and Consistency Rules

- PostgreSQL 是唯一业务事实源：
  - 用户、照片元数据、FRS 外部引用、场次、二维码 token、attempt、record、
    异常记录、审计记录、配置和第三方调用日志都必须落 PostgreSQL。
- 华为云 FRS 仅是托管识别能力和搜索索引：
  - 不保存本地 embedding，不以 FRS 返回结果替代本地 `userId` 或 `recordId`。
- 华为云 OBS 仅是对象存储：
  - 数据库保存 `bucket`、`region`、`objectKey`、`contentType`、`sizeBytes`、
    `sha256`、`storageProvider` 等元数据。
- 应用层生成 `photoId`、`attemptId`、`sessionId`，以便在持久化前构造稳定的 OBS 路径。
- 删除人脸照片遵循“先禁用、后补偿”：
  - 数据库状态先变更，再异步删除 OBS 对象与 FRS `face_id`。
- 历史签到记录永不因删除照片而被物理删除或改写。

### Runtime Flow Decisions

#### 1. 人脸照片上传与异步注册

1. 登录用户或管理员通过后端上传图片。
2. 后端校验大小、扩展名、MIME、可解码性，并计算 `sha256`。
3. 先校验当前用户未删除照片数是否小于 5；若已达上限，直接拒绝上传。
4. 生成 `photoId`，通过 `HuaweiObsStorageService` 上传到
   `faces/user/{userId}/{photoId}.jpg`。
5. 在 PostgreSQL 创建 `FacePhoto(registerStatus=PENDING)`。
6. 投递 `FacePhotoRegisterTask(photoId, userId)` 到 RabbitMQ。
7. 消费者读取照片并调用 `FaceRecognitionProvider.detectFace`。
8. 若无人脸、多张人脸或质量不合格，则更新 `FacePhoto` 为 `FAILED`。
9. 合格后调用 `FaceRecognitionProvider.enrollFace`，设置 `externalImageId=facePhotoId`，
   `externalFields={userId,facePhotoId}`。
10. 成功后写入 `HuaweiFaceRef`，并把 `FacePhoto.registerStatus` 更新为 `ACTIVE`。
11. 若 FRS 失败、超时或重试耗尽，则更新为 `FAILED`，保留原因并要求用户重新上传。

#### 2. 扫码免登录签到

1. 管理员创建并发布场次，系统生成高熵 `qrToken`。
2. App 扫码后调用公开场次解析接口，后端校验 token、状态和时间窗口。
3. App 生成 `idempotencyKey` 并提交签到图片。
4. 后端先做 Redis 限流，再做幂等检查；命中旧结果直接返回首次结果。
5. 后端生成 `attemptId`，上传图片到
   `checkins/session/{sessionId}/attempt/{attemptId}.jpg`。
6. PostgreSQL 写入 `AttendanceCheckinAttempt(PROCESSING)`。
7. 第一阶段同步调用 `FaceRecognitionProvider.detectFace`。
8. 若无人脸、多张人脸或低质量，则 attempt 更新为 `FAILED`。
9. 合格后调用 `FaceRecognitionProvider.searchFace`。
10. 通过 `frsFaceId` 或 `externalFields` 映射 `HuaweiFaceRef -> userId`。
11. 对最佳候选调用 `FaceRecognitionProvider.compareFace` 进行二次确认。
12. 若无匹配、低置信度、比对失败、映射冲突或 FRS 异常，则写失败或人工复核结果。
13. 若匹配成功，则尝试创建 `AttendanceRecord`。
14. 若唯一约束冲突，则将 attempt 更新为 `DUPLICATE_CHECKIN` 并返回已签到。
15. 若创建成功，则 attempt 更新为 `SUCCESS`，返回签到成功结果。

#### 3. Check-in 异步扩展位

- Phase 1 主路径同步调用 FRS，以减少前端轮询复杂度。
- 但 `AttendanceCheckinAttempt`、`attemptId` 查询接口、`PROCESSING` 主状态、
  RabbitMQ 队列命名和消费者边界都在设计上保留。
- 后续可在高峰或 FRS 降级模式下，把“第 7 步之后”切换为队列异步执行，而不改动对外契约。

### Redis and RabbitMQ Design

- Redis keys
  - `auth:blacklist:{jti}`: 被注销 Token 黑名单，TTL 与 Token 剩余寿命一致
  - `checkin:rate:{sessionId}:{clientIp|deviceId}`: 免登录签到限流桶
  - `checkin:idempotency:{idempotencyKey}`: 状态和最终结果缓存，TTL 至少到场次截止后 24 小时
  - `session:qr:{qrToken}`: `qrToken -> sessionId` 的短期解析缓存
- RabbitMQ queues
  - `face.photo.register`
  - `face.photo.register.retry`
  - `face.photo.register.dlq`
  - `face.photo.delete.compensate`
  - `face.photo.delete.compensate.retry`
  - 预留 `checkin.process` 及其 retry/dlq 供 Phase 2 启用

### Security and Audit

- 登录接口统一签发 JWT，携带 `sub`、`role`、`userId`、`jti`、过期时间等 claims。
- 管理员页面和接口只接受 `role=ADMIN`。
- 未登录扫码链路只开放：
  - 场次解析
  - 图片提交
  - Attempt 结果查询
- App 端不保存华为云 AK/SK、OBS 凭证或任何云端直连配置，也不直接访问 PostgreSQL、
  Redis、RabbitMQ、OBS、FRS 或服务器文件系统。
- 所有管理员关键操作写 `AuditLog`：
  - 用户新增/编辑/停用
  - 场次创建/发布/关闭/取消
  - 二维码重置
  - 照片删除
  - 异常处理
  - 系统配置修改（第二阶段）
- FRS/OBS 外部调用记录 `requestId`、目标服务、延迟、结果码、重试次数和错误摘要。

### Manual Review Strategy

- 直接失败，不进入人工复核：
  - 无人脸
  - 多人脸
  - 低质量
  - 无效二维码
  - 场次未开始/已截止/已关闭/已取消
  - 明显低于阈值的相似度
- `FAILED` 主状态下使用 `MANUAL_REVIEW` 结果码进入人工复核：
  - FRS 超时且重试耗尽
  - FRS 限流且当前请求已持久化
  - FRS 返回候选但本地 `HuaweiFaceRef` 映射冲突
  - OBS/FRS 删除补偿多次失败
- Phase 1 管理员处理动作：
  - 查看详情
  - 添加处理备注
  - 重试签到识别
  - 标记为已处理/已驳回
- Phase 1 不默认开放“管理员直接手工造一条有效签到记录”的捷径。

### Test Strategy

- Backend unit tests
  - `AuthService`, `CheckinService`, `FacePhotoService`, `AttendanceSessionService`
  - 结果码映射、幂等回放、重复签到分支
- Backend adapter tests
  - `HuaweiFrsClient` with WireMock-like stub
  - `HuaweiObsStorageService` with mock/test profile
  - `MockFaceRecognitionProvider` behavior tests
- Backend integration tests
  - PostgreSQL Testcontainers for constraints, queries, and transaction behavior
  - Redis Testcontainers for blacklist, idempotency, and rate-limit semantics
  - RabbitMQ Testcontainers for registration task, retry, and DLQ flow
  - End-to-end sign-in flow tests with `MockFaceRecognitionProvider`
- Real Huawei verification
  - 默认不纳入自动化测试或压测链路
  - 全部开发完成后再进行少量真实华为云人工验证
- Flutter tests
  - 登录与状态恢复
  - 路由守卫
  - Dio client 认证头与错误处理
  - 扫码场次解析、拍照签到、结果展示状态流
- Android validation
  - 摄像头权限
  - 扫码能力
  - 图片读取与压缩
  - 文件上传
  - 网络访问
  - 本地安全存储
  - 未登录扫码签到完整链路

## Complexity Tracking

无宪法违规项，也没有需要额外豁免的复杂度例外。本方案刻意拒绝以下备选复杂度：

- 不引入本地 OpenCV/ONNX 推理链路。
- 不引入独立远程自建人脸识别服务。
- 不把 Redis、RabbitMQ、FRS 或 OBS 当作业务事实源。
