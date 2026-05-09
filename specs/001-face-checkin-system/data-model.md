# Data Model: 管理员场次人脸签到系统

## Modeling Principles

- PostgreSQL 是唯一业务事实源。
- 华为云 FRS 只保存托管人脸索引，不替代 `personId`、`facePhotoId`、`sessionId`、
  `attemptId`、`recordId` 等内部标识。
- 华为云 OBS 只保存图片对象，不替代图片元数据、状态或业务关系。
- 所有主键使用应用层生成的 UUID，便于在持久化前构造稳定的 OBS 对象路径。

## Entities

### User

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Y | 主键 |
| `username` | varchar(64) | Y | 登录名，唯一 |
| `passwordHash` | varchar(255) | Y | 加密后的密码 |
| `role` | enum(`USER`,`ADMIN`) | Y | 固定角色枚举 |
| `personId` | UUID | N | 普通用户必填，管理员可为空 |
| `status` | enum(`ACTIVE`,`LOCKED`,`DISABLED`) | Y | 账号状态 |
| `lastLoginAt` | timestamptz | N | 最近登录时间 |
| `createdAt` | timestamptz | Y | 审计字段 |
| `updatedAt` | timestamptz | Y | 审计字段 |

Validation:

- `username` 唯一，长度 3-64。
- `ADMIN` 账号不得访问普通用户专属的“仅本人”数据接口以外的内容，除非通过管理员入口。
- `USER` 账号必须绑定一个 `Person`。

### Role

`Role` 在第一阶段作为固定枚举域对象存在，不单独建可配置管理表，仅允许：

- `USER`
- `ADMIN`

理由：系统只有两类固定角色，单独做角色管理表只会增加无收益复杂度。

### Person

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Y | 主键 |
| `personCode` | varchar(64) | Y | 人员编号，唯一 |
| `displayName` | varchar(100) | Y | 展示名 |
| `realName` | varchar(100) | Y | 真实姓名 |
| `phone` | varchar(32) | N | 联系方式 |
| `email` | varchar(128) | N | 联系邮箱 |
| `enabled` | boolean | Y | 是否可用于识别与签到 |
| `createdAt` | timestamptz | Y | 审计字段 |
| `updatedAt` | timestamptz | Y | 审计字段 |

Validation:

- `personCode` 唯一。
- 被禁用人员不能生成新的有效签到记录。

### FacePhoto

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Y | 主键 |
| `personId` | UUID | Y | 归属人员 |
| `obsBucket` | varchar(128) | Y | OBS bucket |
| `obsObjectKey` | varchar(255) | Y | 对象路径，建议 `faces/person/{personId}/{photoId}.jpg` |
| `contentType` | varchar(64) | Y | 图片类型 |
| `sizeBytes` | bigint | Y | 文件大小 |
| `sha256` | varchar(64) | Y | 文件哈希 |
| `detectStatus` | enum(`PENDING`,`PASSED`,`FAILED`) | Y | 检测状态 |
| `registerStatus` | enum(`PENDING`,`ACTIVE`,`FAILED`,`DISABLED`,`DELETE_PENDING`,`DELETE_FAILED`,`DELETED`) | Y | FRS 注册状态 |
| `failureReason` | varchar(255) | N | 失败原因摘要 |
| `failureCode` | varchar(64) | N | 标准化失败码 |
| `enabled` | boolean | Y | 当前是否启用 |
| `createdByUserId` | UUID | Y | 谁上传的 |
| `createdAt` | timestamptz | Y | 审计字段 |
| `updatedAt` | timestamptz | Y | 审计字段 |

Validation:

- 单张图片大小 `<= 10 MB`。
- 格式只允许 `JPEG`、`PNG`、`WEBP`。
- 同一人员最多允许 5 张 `enabled=true` 且 `registerStatus=ACTIVE` 的照片。

### HuaweiFaceRef

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Y | 主键 |
| `personId` | UUID | Y | 归属人员 |
| `facePhotoId` | UUID | Y | 归属照片 |
| `faceSetName` | varchar(128) | Y | FRS face set |
| `frsFaceId` | varchar(128) | Y | 华为云返回 face_id |
| `externalImageId` | varchar(128) | Y | 默认绑定 `facePhotoId` |
| `externalFields` | jsonb | Y | 至少包含 `personId`、`facePhotoId` |
| `status` | enum(`ACTIVE`,`DELETE_PENDING`,`DELETE_FAILED`,`DELETED`,`ORPHANED`) | Y | 外部引用状态 |
| `createdAt` | timestamptz | Y | 审计字段 |
| `updatedAt` | timestamptz | Y | 审计字段 |

Validation:

- `frsFaceId` 全局唯一。
- `facePhotoId` 在 `ACTIVE` 状态下只能对应一个当前有效引用。

### AttendanceSession

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Y | 主键 |
| `name` | varchar(128) | Y | 场次名称 |
| `description` | text | N | 场次说明 |
| `startTime` | timestamptz | Y | 开始时间 |
| `endTime` | timestamptz | Y | 截止时间 |
| `lateAfterTime` | timestamptz | N | 第一阶段预留，可为空 |
| `status` | enum(`DRAFT`,`PUBLISHED`,`CLOSED`,`CANCELED`) | Y | 场次状态 |
| `qrToken` | varchar(128) | Y | 当前有效二维码 token |
| `createdBy` | UUID | Y | 管理员用户 ID |
| `createdAt` | timestamptz | Y | 审计字段 |
| `updatedAt` | timestamptz | Y | 审计字段 |

Validation:

- `startTime < endTime`。
- `qrToken` 必须高熵且唯一。
- 第一阶段只允许 `PUBLISHED` 且当前时间在有效窗口内签到。

### AttendanceCheckinAttempt

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Y | attemptId，主键 |
| `sessionId` | UUID | Y | 所属场次 |
| `obsBucket` | varchar(128) | Y | 签到照片所在 bucket |
| `obsObjectKey` | varchar(255) | Y | 建议 `checkins/session/{sessionId}/attempt/{attemptId}.jpg` |
| `status` | enum(`PROCESSING`,`SUCCESS`,`FAILED`,`DUPLICATE_CHECKIN`,`MANUAL_REVIEW`) | Y | 对外主状态 |
| `resultCode` | varchar(64) | Y | 细粒度结果码 |
| `failureReason` | varchar(255) | N | 面向业务的失败摘要 |
| `frsRequestId` | varchar(128) | N | 第三方 requestId |
| `matchedPersonId` | UUID | N | 匹配到的人员 |
| `matchedFaceId` | varchar(128) | N | 匹配到的 FRS face_id |
| `similarity` | numeric(5,2) | N | 相似度 |
| `idempotencyKey` | varchar(128) | Y | 幂等键 |
| `clientIp` | varchar(64) | N | 来源 IP |
| `deviceId` | varchar(128) | N | 移动端设备标识 |
| `createdAt` | timestamptz | Y | 创建时间 |
| `updatedAt` | timestamptz | Y | 最终结果更新时间 |

Validation:

- `(sessionId, idempotencyKey)` 唯一。
- `SUCCESS` 或 `DUPLICATE_CHECKIN` 时必须有 `matchedPersonId`。

### AttendanceRecord

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Y | 主键 |
| `sessionId` | UUID | Y | 所属场次 |
| `personId` | UUID | Y | 签到人员 |
| `attemptId` | UUID | Y | 来源 attempt |
| `checkinTime` | timestamptz | Y | 签到时间 |
| `status` | enum(`VALID`,`MANUAL_CONFIRMED`) | Y | 第一阶段默认 `VALID` |
| `similarity` | numeric(5,2) | N | 命中相似度 |
| `source` | enum(`APP_QR_ANON`,`ADMIN_RETRY`) | Y | 来源 |
| `createdAt` | timestamptz | Y | 审计字段 |

Validation:

- `(sessionId, personId)` 唯一。
- 删除照片或外部引用不会级联删除历史 `AttendanceRecord`。

### AuditLog

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Y | 主键 |
| `actorUserId` | UUID | Y | 管理员 ID 或系统用户 ID |
| `actorRole` | varchar(32) | Y | 触发者角色 |
| `action` | varchar(128) | Y | 动作名称 |
| `targetType` | varchar(64) | Y | 目标实体类型 |
| `targetId` | UUID | N | 目标实体 ID |
| `summary` | varchar(255) | Y | 操作摘要 |
| `detailJson` | jsonb | N | 补充细节 |
| `createdAt` | timestamptz | Y | 审计时间 |

### SystemConfig

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Y | 主键 |
| `configKey` | varchar(128) | Y | 配置键 |
| `configValue` | text | Y | 配置值 |
| `valueType` | enum(`STRING`,`NUMBER`,`BOOLEAN`,`JSON`) | Y | 值类型 |
| `description` | varchar(255) | N | 配置说明 |
| `updatedBy` | UUID | Y | 修改人 |
| `updatedAt` | timestamptz | Y | 修改时间 |

Recommended keys:

- `frs.face-set-name`
- `frs.similarity-threshold`
- `frs.liveness-enabled`
- `checkin.idempotency-ttl-hours`
- `checkin.rate-limit-window-seconds`
- `checkin.rate-limit-max-requests`

### ExternalServiceCallLog

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Y | 主键 |
| `serviceName` | enum(`HUAWEI_FRS`,`HUAWEI_OBS`) | Y | 外部服务名 |
| `operation` | varchar(64) | Y | 具体操作，如 `DetectFace` |
| `requestId` | varchar(128) | N | 外部 requestId |
| `relatedEntityType` | varchar(64) | N | 关联实体类型 |
| `relatedEntityId` | UUID | N | 关联实体 ID |
| `status` | enum(`SUCCESS`,`FAILED`,`TIMEOUT`,`RATE_LIMITED`,`RETRYING`) | Y | 调用结果 |
| `latencyMs` | integer | N | 耗时 |
| `errorCode` | varchar(64) | N | 错误码 |
| `errorSummary` | varchar(255) | N | 错误摘要 |
| `createdAt` | timestamptz | Y | 审计时间 |

## Relationships

- `User (USER)` `1 -> 1` `Person`
- `User (ADMIN)` `0 -> 1` `Person`
- `Person 1 -> N FacePhoto`
- `FacePhoto 1 -> 0..N HuaweiFaceRef`
- `AttendanceSession 1 -> N AttendanceCheckinAttempt`
- `AttendanceSession 1 -> N AttendanceRecord`
- `AttendanceCheckinAttempt 1 -> 0..1 AttendanceRecord`
- `Person 1 -> N AttendanceRecord`
- `User 1 -> N AuditLog`
- `FacePhoto/Attempt/Session 1 -> N ExternalServiceCallLog`

## State Transitions

### FacePhoto Lifecycle

```text
PENDING / PENDING
  -> PASSED / PENDING
  -> PASSED / ACTIVE
  -> FAILED / FAILED
  -> PASSED / DELETE_PENDING
  -> PASSED / DELETE_FAILED
  -> PASSED / DELETED
```

Interpretation:

- 上传成功后初始为 `detectStatus=PENDING, registerStatus=PENDING`
- 通过检测后进入注册流程
- 注册成功后进入 `ACTIVE`
- 删除请求先进入 `DELETE_PENDING`，补偿完成后 `DELETED`

### HuaweiFaceRef Lifecycle

```text
ACTIVE -> DELETE_PENDING -> DELETED
ACTIVE -> DELETE_PENDING -> DELETE_FAILED
ACTIVE -> ORPHANED
```

`ORPHANED` 用于 FRS 数据与本地状态不一致但尚未恢复的场景。

### AttendanceSession Lifecycle

```text
DRAFT -> PUBLISHED -> CLOSED
DRAFT -> CANCELED
PUBLISHED -> CANCELED
```

第一阶段不允许 `CLOSED` 回退到 `PUBLISHED`。

### AttendanceCheckinAttempt Lifecycle

```text
PROCESSING -> SUCCESS
PROCESSING -> FAILED
PROCESSING -> DUPLICATE_CHECKIN
PROCESSING -> MANUAL_REVIEW
MANUAL_REVIEW -> FAILED
MANUAL_REVIEW -> SUCCESS   (仅管理员重试成功后)
```

### AttendanceRecord Lifecycle

```text
VALID
VALID -> MANUAL_CONFIRMED  (仅后续扩展需要时启用)
```

第一阶段正常自动签到只生成 `VALID`。

## Indexes and Constraints

| Table | Constraint / Index | Purpose |
|---|---|---|
| `user` | unique(`username`) | 登录名唯一 |
| `person` | unique(`person_code`) | 人员编号唯一 |
| `face_photo` | index(`person_id`, `enabled`, `register_status`) | 查询当前可用照片 |
| `face_photo` | unique(`sha256`, `person_id`) optional | 同人重复图片检测 |
| `huawei_face_ref` | unique(`frs_face_id`) | 外部 face_id 唯一 |
| `huawei_face_ref` | unique(`face_photo_id`, `status`) filtered active | 单张照片当前有效引用唯一 |
| `attendance_session` | unique(`qr_token`) | 当前二维码 token 唯一 |
| `attendance_session` | index(`status`, `start_time`, `end_time`) | 场次查询与校验 |
| `attendance_checkin_attempt` | unique(`session_id`, `idempotency_key`) | 幂等落库保护 |
| `attendance_checkin_attempt` | index(`session_id`, `created_at`) | 场次尝试列表 |
| `attendance_checkin_attempt` | index(`matched_person_id`, `created_at`) | 异常追溯 |
| `attendance_record` | unique(`session_id`, `person_id`) | 防重复有效签到 |
| `attendance_record` | index(`person_id`, `checkin_time`) | 个人历史记录 |
| `audit_log` | index(`actor_user_id`, `created_at`) | 审计查询 |
| `external_service_call_log` | index(`service_name`, `created_at`) | 外部调用审计 |

## Derived Rules

- 任一 `Person` 若不存在至少一张 `FacePhoto(registerStatus=ACTIVE, enabled=true)`，
  则不能被成功识别签到。
- `AttendanceRecord` 的创建必须依赖 `AttendanceCheckinAttempt`。
- Attempt 失败、重复或人工复核都必须可查询，不能只在日志中存在。
- 清理历史图片或外部引用时，不能破坏既有签到记录与审计记录的可追溯性。
