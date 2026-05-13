# FaceCheck 设计文档

## 1. 目标与范围
- 交付完整的人脸签到系统：管理员场次管理、匿名扫码签到、个人照片库、个人与全局签到记录。
- 后端保持 Spring Boot 单体作为唯一业务边界。
- 人脸识别使用华为云 FRS，图片存储使用华为云 OBS。
- 匿名用户、普通用户、管理员三类访问边界清晰隔离。

## 2. 非目标
- 不拆分微服务。
- 不引入本地 OpenCV/ONNX 推理。
- 客户端不直连 FRS/OBS/PostgreSQL/Redis/RabbitMQ。
- 第一阶段不做活体检测。

## 3. 架构概览

系统上下文：

  Flutter App
     |
     v
  Spring Boot 单体
     |-- auth / identity / session / checkin / admin
     |-- face (FaceRecognitionProvider)
     |-- storage (OBS 适配)
     |
     |--> PostgreSQL (事实源)
     |--> Redis (限流/幂等/黑名单/二维码缓存)
     |--> RabbitMQ (人脸照片异步注册)
     |--> Huawei Cloud FRS
     |--> Huawei Cloud OBS

关键边界：
- App 只调用后端 API。
- FRS/OBS 只由后端访问。
- PostgreSQL 是唯一业务事实源。

## 4. 模型选择

### 4.1 人脸识别模型
- 提供方：华为云 FRS。
- 调用链路：detect -> search -> compare。
- 抽象：FaceRecognitionProvider，生产实现为 HuaweiCloudFrsFaceRecognitionProvider，测试实现为 MockFaceRecognitionProvider。
- 理由：符合约束，避免本地推理，便于替换与测试隔离。

### 4.2 图片存储
- 提供方：华为云 OBS。
- 对象路径：
  - 人脸照片：faces/user/{userId}/{photoId}.jpg
  - 签到照片：checkins/session/{sessionId}/attempt/{attemptId}.jpg
- 理由：对象存储适合二进制图片，元数据与业务关系仍由 PostgreSQL 维护。

### 4.3 数据与消息
- PostgreSQL：用户、场次、照片、attempt、record、审计日志、外部调用日志的权威存储。
- Redis：Token 黑名单、限流、幂等结果缓存、二维码解析缓存。
- RabbitMQ：人脸照片异步注册、重试与死信。

## 5. 关键数据模型

第一阶段核心实体：
- User：统一账号模型，用户名是唯一登录标识，不引入 Person 模型。
- FacePhoto：照片元数据、校验状态、注册状态与失败原因。
- HuaweiFaceRef：FRS 外部引用，映射本地 userId 与 facePhotoId。
- AttendanceSession：场次与 qrToken 生命周期管理。
- AttendanceCheckinAttempt：每次签到尝试的状态与结果码。
- AttendanceRecord：有效签到结果，按 (sessionId, userId) 唯一。
- AuditLog：管理员关键操作审计。
- ExternalServiceCallLog：FRS/OBS 调用审计。
- SystemConfig：白名单配置项。

约束：
- AttendanceRecord 唯一约束 unique(session_id, user_id)。
- AttendanceCheckinAttempt 唯一约束 unique(session_id, idempotency_key)。
- qrToken 高熵且唯一。

## 6. 关键流程

### 6.1 人脸照片上传与异步注册
1. 登录用户或管理员上传照片。
2. 后端校验大小、MIME、扩展名、可解码性（<=10MB，JPEG/PNG/WEBP）。
3. 后端强制每人最多 5 张可用照片。
4. 上传到 OBS，创建 FacePhoto(PENDING_REGISTER)。
5. 发送 FacePhotoRegisterTask 到 RabbitMQ。
6. 消费者通过 FaceRecognitionProvider 完成 detect + enroll。
7. 成功写 HuaweiFaceRef 并标记 FacePhoto ACTIVE；失败写入原因。

### 6.2 匿名扫码签到
1. 管理员发布场次并生成 qrToken。
2. App 扫码调用公开入口确认场次可用。
3. 提交签到照片与 idempotencyKey、deviceId。
4. 后端限流与幂等检查。
5. 生成 AttendanceCheckinAttempt 并上传签到照片。
6. 执行 detect -> search -> compare。
7. 映射候选到 userId 并按阈值判断。
8. 成功写 AttendanceRecord；唯一约束冲突返回 DUPLICATE_CHECKIN。
9. 返回 SUCCESS/FAILED/PROCESSING/DUPLICATE_CHECKIN。

### 6.3 场次生命周期
- Draft -> Published -> Closed，或 Draft/Published -> Canceled。
- qrToken 轮换后旧 token 失效。

## 7. 安全与权限
- JWT 保护需要登录的接口，注销写入 Redis 黑名单。
- 普通用户只能访问自身数据。
- 管理员接口仅限管理员角色。
- 匿名接口仅限场次解析、签到提交与结果查询。

## 8. 结果与错误码
- 主状态：SUCCESS、FAILED、PROCESSING、DUPLICATE_CHECKIN。
- 关键结果码：
  - INVALID_IMAGE、NO_FACE、MULTIPLE_FACES、LOW_CONFIDENCE
  - EXPIRED_SESSION、SESSION_CLOSED、SESSION_CANCELED
  - FRS_TIMEOUT、FRS_RATE_LIMITED、FRS_ERROR
  - MANUAL_REVIEW

## 9. 可观测性与审计
- 请求链路统一注入 traceId。
- AuditLog 记录管理员关键操作。
- ExternalServiceCallLog 记录 FRS/OBS 调用 requestId 与耗时。

## 10. 测试策略
- MockFaceRecognitionProvider 覆盖单元与集成测试。
- Testcontainers 覆盖 PostgreSQL、Redis、RabbitMQ。
- 关键 API 合同测试与集成测试。
- Android 模拟器或真机验证扫码、拍照、上传与匿名签到流程。

## 11. 风险与缓解
- FRS 不稳定：用明确结果码和 attempt 记录可追溯失败。
- 重复提交：幂等缓存 + 数据库唯一约束双重保护。
- 照片质量：上传阶段前置校验并输出明确失败原因。

## 12. 后续扩展
- 可切换为异步签到处理，但保持 PROCESSING 与结果查询契约不变。
- 系统状态/配置页面作为第二阶段扩展。
