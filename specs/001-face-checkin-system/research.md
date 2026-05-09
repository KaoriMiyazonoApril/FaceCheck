# Research: 管理员场次人脸签到系统

## Decision 1: 保持 Spring Boot 单体，按业务边界精简模块

- Decision: 后端保持 Spring Boot 单体，按 `auth`、`identity`、`face`、`storage`、
  `session`、`checkin`、`admin`、`common`、`infrastructure` 划分模块；Flutter App
  保持单一移动端工程。
- Rationale: 这与项目宪法、课程交付复杂度和现有 Spec 完全一致，能把权限、签到规则、
  幂等、防重复、审计和第三方云服务编排集中在一个事务与日志边界内。
- Alternatives considered:
  - 微服务拆分：违反宪法，增加分布式一致性与部署复杂度。
  - 独立远程人脸识别服务：违反“不得自建或拆分独立识别微服务”的约束。

## Decision 2: 运行时基线采用 Java 21 LTS + Spring Boot 3.x，Flutter stable + Dart 3.x

- Decision: 规划阶段固定 Java 21 LTS、Spring Boot 3.x、Flutter stable、Dart 3.x，
  具体补丁版本在实际脚手架创建时锁定。
- Rationale: Java 21 是当前长期支持版本，适合 Spring Boot 3 生态；Flutter stable
  与 Dart 3.x 足够支撑 Android 端扫码、相机和安全存储能力。
- Alternatives considered:
  - Java 17：可行，但在新项目里没有明显优于 Java 21 的收益。
  - 精确锁定某个 patch 版本：当前仓库还没有构建文件，过早钉死 patch 价值不高。

## Decision 3: 通过 FaceProvider 抽象统一封装华为云 FRS

- Decision: `face` 模块定义 `FaceProvider` 接口，提供 `detectFace`、`enrollFace`、
  `searchFace`、`deleteFace` 和可选 `checkLiveness` 能力；生产实现为
  `HuaweiFrsFaceProvider`，本地与自动化测试使用 `MockFaceProvider`。
- Rationale: 业务层只依赖 Provider 抽象，才能把人脸识别供应商变化、超时、重试和错误
  语义控制在基础设施边界内，保持 PostgreSQL 事实源不被 FRS 反向主导。
- Alternatives considered:
  - 业务服务直接依赖华为云 SDK：测试和替换成本过高，违反宪法的 Provider 抽象要求。
  - 本地 OpenCV/ONNX 推理：与当前性能约束和宪法相冲突。

## Decision 4: FRS 调用采用 HuaweiFrsClient 统一 REST 适配

- Decision: `HuaweiFrsClient` 作为基础设施客户端，集中处理签名、超时、重试、错误映射、
  结构化日志和 requestId 透传；`HuaweiFrsFaceProvider` 负责把客户端结果映射为领域结果。
- Rationale: FRS 只需要有限的人脸检测、入库、搜索与删除接口，使用统一 REST Client
  更容易进行 WireMock 级别的适配测试，也更容易控制请求超时与响应解析。
- Alternatives considered:
  - 直接在 Provider 中拼 HTTP：横切逻辑分散，不利于测试与复用。
  - 全量依赖厂商业务层 SDK：可行，但在本项目范围内对测试隔离不如轻量 Client 明确。

## Decision 5: 图片持久化使用 OBS，对外访问通过后端受控暴露

- Decision: 所有人脸照片和签到照片持久化到华为云 OBS；`HuaweiObsStorageService`
  负责上传、删除、对象键生成和临时访问 URL；PostgreSQL 只保存对象元数据与业务关联。
- Rationale: 图片二进制不适合长期存 PostgreSQL；OBS 适合对象存储，但不能承担业务事实源。
  后端受控发放临时 URL 或代理读取，才能满足最小暴露原则。
- Alternatives considered:
  - 数据库存 BLOB：存储和备份成本过高。
  - Flutter 直传 OBS：违反后端统一校验和凭证不下发到 App 的要求。
  - 长期公开 URL：不满足敏感图片最小暴露要求。

## Decision 6: 人脸照片注册异步化，签到识别 Phase 1 同步执行并保留 PROCESSING 扩展

- Decision: 人脸照片上传在请求线程中只做文件校验、OBS 上传和元数据落库，然后投递
  `FacePhotoRegisterTask` 到 RabbitMQ；签到识别第一阶段在 HTTP 请求内同步完成 DetectFace
  和 SearchFace，但统一通过 `AttendanceCheckinAttempt` 状态机建模，保留 future
  queue-based `PROCESSING` 扩展点。
- Rationale: 用户上传照片的等待时间最容易被异步化；而签到第一阶段优先追求闭环可用与反馈直观。
  统一 attempt 状态机后，后续再把高峰签到切到异步消费者时不需要重写业务模型。
- Alternatives considered:
  - 上传照片同步注册 FRS：响应时间不可控，用户体验差。
  - 第一阶段签到也强制异步：会增加结果轮询与异常排查复杂度，不利于最小闭环交付。

## Decision 7: Redis 仅承担幂等、限流、Token 黑名单和二维码解析缓存

- Decision: Redis 用于 JWT 黑名单、扫码签到限流、`idempotencyKey` 处理状态、短期
  `qrToken -> sessionId` 解析缓存，以及必要的短期会话辅助；任何用户、人员、照片、
  场次、签到或异常数据都不以 Redis 为唯一来源。
- Rationale: Redis 擅长低延迟保护逻辑，但不适合做唯一业务事实。将其限制在支撑层，
  可以避免缓存丢失或过期导致业务结果失真。
- Alternatives considered:
  - 在 Redis 中保存签到主记录：违背宪法的事实源要求。
  - 不做 Redis 幂等：移动网络抖动下重复提交风险过高。

## Decision 8: 主数据模型围绕 Person、FacePhoto、HuaweiFaceRef、Session、Attempt、Record

- Decision: 普通用户账户与管理员账户统一为 `User`，角色采用固定枚举；普通用户与 `Person`
  绑定，管理员可不绑定 `Person`。人脸资料拆成 `FacePhoto` 与 `HuaweiFaceRef` 两层；
  签到链路拆成 `AttendanceSession`、`AttendanceCheckinAttempt` 和 `AttendanceRecord`。
- Rationale: 账户权限和可识别人员不是同一概念。把人脸照片元数据与 FRS 外部引用拆开，
  才能在删除、重试、补偿和历史追溯时保持清晰边界。
- Alternatives considered:
  - 把 `Role` 做成独立可配置表：当前只有 USER/ADMIN 两种固定角色，收益低。
  - 把 `FacePhoto` 与 `HuaweiFaceRef` 合并：会把对象存储元数据、外部 faceId 状态和删除
    补偿语义混在一起。

## Decision 9: 重复签到靠数据库唯一约束兜底，幂等与限流作为前置保护

- Decision: `AttendanceRecord` 以 `(session_id, person_id)` 建唯一约束作为最终防线；
  Redis 负责前置限流与幂等结果复用；Attempt 始终先落库，便于记录失败、重复和异常语义。
- Rationale: Redis 不能替代数据库唯一性。唯一约束能在并发和重试场景下保证“同人同场次”
  最多一条有效签到记录。
- Alternatives considered:
  - 只靠 Redis 锁：锁失效或网络分区下仍可能出现重复记录。
  - 只记录成功不记录 attempt：会失去失败和异常审计能力。

## Decision 10: 手动复核只处理“结果不确定”而非明显坏图

- Decision: `MANUAL_REVIEW` 只用于 FRS 超时、限流、多候选映射冲突、外部删除补偿失败、
  或系统内部不确定状态；无人脸、多人脸、无效二维码、低质量和明显低置信度直接返回失败。
- Rationale: 明确把“可直接判错”和“需要人工判断”分开，能降低管理员噪音并保持异常处理成本
  可控。
- Alternatives considered:
  - 所有失败都进入人工复核：管理成本过高。
  - 完全没有人工复核：外部依赖异常时无法保留后续处理空间。

## Decision 11: 删除照片采用“先禁用、后补偿”的一致性策略

- Decision: 删除人脸照片时，先在 PostgreSQL 中把 `FacePhoto.enabled` 置为 false，并把
  `HuaweiFaceRef` 标记为 `DELETE_PENDING`；随后异步删除 OBS 对象与 FRS `face_id`，
  成功后更新为 `DELETED`，失败则记录 `DELETE_FAILED` 并允许后台重试。
- Rationale: OBS 和 FRS 删除都属于跨系统副作用，不能放在单数据库事务里强一致完成。
- Alternatives considered:
  - 先删云端再改数据库：数据库更新失败会留下不可恢复的状态偏差。
  - 同步串行删除并阻塞请求：用户体验差，且对外部超时敏感。

## Decision 12: 测试分层采用 Mock Provider + WireMock + Testcontainers + Android 验证

- Decision: 业务测试默认使用 `MockFaceProvider`；`HuaweiFrsClient` 适配层使用 WireMock
  或等价 HTTP mock；OBS 服务使用 mock 或 test profile 替身；PostgreSQL、Redis、
  RabbitMQ 采用 Testcontainers；Flutter 侧覆盖登录、路由、API Client、状态流转、
  扫码签到和页面测试；摄像头、扫码、权限、拍照上传和未登录签到链路在 Android 真机或
  模拟器验证。
- Rationale: 这样可以在没有真实云凭证时跑通绝大多数自动化测试，同时保留少量显式开启的
  云端集成测试入口。
- Alternatives considered:
  - 所有测试都依赖真实华为云：成本高且不稳定。
  - 只做单元测试不做容器集成测试：无法验证 PostgreSQL 唯一约束、Redis 幂等和 RabbitMQ
    重试语义。
