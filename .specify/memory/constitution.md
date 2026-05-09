<!--
Sync Impact Report
Version change: 1.1.0 -> 1.2.0
Modified principles:
- II. 华为云 FRS 统一封装与 Provider 抽象：移除活体检测基线，固定 search 后 compare 的识别链路
- III. 最小可交付签到闭环与角色边界：取消人员/用户双模型，固定为用户账号模型
- IV. PostgreSQL 事实源、OBS 对象存储与受控异步边界：唯一约束改为 `unique(session_id, user_id)`
- V. 安全边界、状态结果与测试门禁：固定四类对外主状态，并把真实华为云验证降为开发完成后的少量人工验证
Added sections:
- 华为云 FRS 集成约束
- 华为云 OBS 集成约束
Removed sections:
- 无
Templates requiring updates:
- ✅ updated .specify/templates/plan-template.md
- ✅ updated .specify/templates/spec-template.md
- ✅ updated .specify/templates/tasks-template.md
- ✅ updated specs/001-face-checkin-system/spec.md
- ✅ updated specs/001-face-checkin-system/plan.md
- ✅ updated specs/001-face-checkin-system/tasks.md
Runtime docs updated:
- ✅ updated readme.md
Follow-up TODOs:
- 无
-->
# 人脸签到系统项目宪法

## Core Principles

### I. 单体后端、固定技术栈与华为云 FRS/OBS 基线
后端 MUST 保持为单个 Spring Boot 应用，禁止在未同步更新 `spec`、`plan` 和
`tasks` 的情况下拆分为微服务或替换核心技术栈。后端 MUST 使用 Spring Boot、
Spring Data JPA、PostgreSQL、Redis、RabbitMQ、JWT、Flyway、Docker Compose、
Testcontainers、华为云 FRS、华为云 OBS，以及华为云 FRS SDK 或统一 REST Client
封装；App 端 MUST 使用 Flutter、Dart、Dio 或统一 HTTP Client、Riverpod、
`go_router` 或统一路由封装、Flutter 相机或图片选择能力，以及本地安全存储。
第一版 MUST 以华为云 FRS 作为托管人脸识别能力来源，并以华为云 OBS 作为图片对象
存储基线；除非宪法与下游文档同步修订，否则 MUST NOT 替换为其他云厂商、自建模型、
本地推理库、独立远程识别服务或其他正式图片存储基线。

理由：当前服务器性能不足以稳定承载完整本地推理链路，必须先把业务闭环建立在受控的托管
识别能力之上。

### II. 华为云 FRS 统一封装与 Provider 抽象
所有华为云 FRS 调用 MUST 由 Spring Boot 后端统一封装、鉴权、限流、审计和错误处理。
Flutter App MUST NOT 直接调用华为云 FRS，也 MUST NOT 保存华为云 AK/SK 或其他
敏感凭证。Flutter App MUST 只通过 Spring Boot 后端 API 访问业务数据，MUST NOT
直接访问 PostgreSQL、Redis、RabbitMQ、华为云 OBS、服务器文件系统或其他后端
内部依赖。业务代码 MUST 通过 `FaceRecognitionProvider` 抽象访问人脸能力，并提供
第一版实现 `HuaweiCloudFrsFaceRecognitionProvider`；业务流程 MUST 依赖接口，
MUST NOT 直接依赖具体厂商 SDK 或 REST API。后端 MUST 统一封装至少以下能力：
`detectFace`、`enrollFace`、`searchFace`、`compareFace`、`deleteFace`
和外部元数据同步能力。第一版签到识别 MUST 采用“先搜索候选，再做人脸比对确认”的链路，
MUST NOT 依赖活体检测作为签到放行前提。自动化测试与本地开发 MUST 支持
`MockFaceRecognitionProvider`，避免强依赖真实华为云 FRS。

理由：Provider 抽象是未来替换供应商时保持业务流程、权限边界和事实源不被击穿的唯一稳定
接口层。

### III. 最小可交付签到闭环与角色边界
当前版本 MUST 只实现最小可交付的人脸签到系统闭环，并覆盖以下核心能力：用户登录、
管理员登录、管理员新增/编辑/停用用户、用户维护自己的用户名和密码、人脸照片上传与管理、
调用华为云 FRS 进行人脸检测、照片入库、人脸搜索和人脸比对、管理员创建签到场次、设置开始
与截止时间、生成签到二维码、用户通过 Flutter App 扫码进入场次、用户在不登录的情况下提交
签到照片、后端识别签到用户、生成签到记录、用户查看个人签到记录、管理员查看全局签到记录与
场次签到用户、处理异常签到记录，以及限流、幂等和防重复签到控制。系统 MUST 只包含普通用户
和管理员两类角色。系统 MUST 以唯一用户名区分用户，MUST NOT 依赖邮箱、手机号或其他外部
标识作为登录或业务区分主键。普通用户 MAY 管理自己的用户名、密码、照片和签到记录，但
MUST NOT 查看、修改或管理其他用户的数据。管理员 MAY 管理用户、照片库、签到场次、二维码、
记录、异常与必要配置，并且关键操作 MUST 保留审计记录。扫码免登录签到 MUST 只允许进入指定
场次并提交签到照片，MUST NOT 访问个人资料、照片库、历史签到或任何管理员数据。

理由：第一版只交付签到主链路和最小管理闭环，能把范围控制在可验证、可上线的边界内。

### IV. PostgreSQL 事实源、OBS 对象存储与受控异步边界
PostgreSQL MUST 是唯一业务事实源，并 MUST 持久化用户信息（含角色、用户名、密码摘要、
状态）、签到场次信息、二维码或二维码载荷信息、人脸照片元数据、人脸照片与用户绑定关系、
华为云 FRS `faceSetName`、外部 `faceId` 或人脸引用、OBS `bucket`、`region`、
`objectKey`、`contentType`、`sizeBytes`、`sha256`、`storageProvider`、签到请求
attempt 记录、签到记录、异常签到记录、幂等请求记录、管理员操作审计记录，以及第三方
FRS 调用审计信息。华为云 FRS MAY 保存人脸特征与人脸库，但 MUST NOT 替代
PostgreSQL 中的业务数据；`faceId`、`faceSetName`、`similarity`、
`externalRequestId` 等字段只能作为外部引用、诊断或审计信息保存。
华为云 OBS MAY 保存图片对象，但 MUST NOT 替代 PostgreSQL 中的业务元数据与事实记录。
Redis 只能用于缓存、限流、幂等控制、防重复提交、Token 黑名单或会话辅助，以及短期签到
状态查询辅助；RabbitMQ 只能用于异步人脸照片入库、华为云 FRS 添加人脸、第三方调用
失败重试、超时重试、死信处理，以及在后续阶段经 `spec`/`plan` 启用的签到识别削峰。
Redis 和 RabbitMQ MUST NOT 成为核心业务事实源。防重复签到 MUST 同时依赖 Redis
前置保护和数据库唯一约束 `unique(session_id, user_id)`，后者 MUST 作为最终一致性防线。

理由：外部识别服务、缓存和消息队列都可能失败或重试，只有稳定的数据库事实源才能保证
签到结果可追溯且可修复。

### V. 安全边界、状态结果与测试门禁
管理员接口、用户个人信息接口和人脸照片管理接口 MUST 使用 JWT 鉴权。签到上传接口 MAY
免登录，但 MUST 实施场次校验、二维码校验、限流、防刷、防重复和人脸识别校验。文件上传
MUST 限制类型、大小和内容，并校验 MIME、扩展名、真实可解码性、基础清晰度、是否无人脸
或多人脸。人脸照片入库流程 MUST 异步化；签到识别流程第一阶段 MAY 直接同步调用华为云
FRS，但 MUST 保留 `PROCESSING` 主状态、结果查询能力和未来切换为 RabbitMQ
削峰时不破坏外部契约的兼容性；在华为云 FRS 超时、限流、异常返回、低置信度、无脸、
多人脸等情况下 MUST 生成失败记录或异常记录，MUST NOT 静默丢弃请求。签到结果对外
主状态 MUST 只支持 `PROCESSING`、`SUCCESS`、`FAILED` 和 `DUPLICATE_CHECKIN`；
细分原因 MUST 通过标准化结果码表达，且至少覆盖 `MANUAL_REVIEW`、`EXPIRED_SESSION`、
`INVALID_IMAGE`、`NO_FACE`、`MULTIPLE_FACES`、`LOW_CONFIDENCE`、
`FRS_TIMEOUT`、`FRS_RATE_LIMITED` 和 `FRS_ERROR`。Flutter App MUST 以
Android 为主要交付与测试目标，Windows 桌面调试仅用于普通页面、状态流转和接口调用；
凡涉及摄像头、权限申请、图片读取、文件上传、网络访问、扫码、签到拍照流程或结果轮询的
能力，MUST 在 Android 真机或 Android 模拟器中验证。后端 MUST 覆盖用户认证、管理员
权限、用户管理、场次管理、二维码生成、照片上传、照片入库任务、Provider 单元测试、
华为云 FRS 适配层测试、Mock Provider 测试、签到流程、免登录扫码签到、异常记录、
限流、幂等、防重复签到、唯一约束、RabbitMQ 重试与死信、FRS 超时、FRS 限流、
FRS 异常返回，以及 PostgreSQL Testcontainers 集成测试。真实华为云 FRS 或 OBS
验证 MAY 在开发完成后由人工执行少量验证，但 MUST NOT 作为默认自动化门禁前提。

理由：一旦第三方识别能力、异步队列或移动端硬件行为不可控，只有严格的状态模型和测试门禁
才能让系统在失败时仍然可诊断、可审计、可恢复。

## 技术与交付约束

- 项目定位固定为基于 Spring Boot 单体后端与 Flutter 移动端 App 的人脸签到系统。
- 系统核心流程 MUST 是“移动端采集图片或拍照上传 -> 后端统一封装华为云 FRS 完成人脸检测、
  人脸入库、人脸搜索、人脸比对与身份识别，并通过华为云 OBS 持久化图片对象 ->
  本系统生成签到记录 -> 返回签到结果”。
- 后端模块边界 MUST 落在 `auth`、`identity`、`face`、`storage`、`checkin`、
  `session`、`admin`、`common`、`infrastructure` 内，或在 `plan`
  中给出等价映射。
- Docker Compose MUST 作为本地基础设施编排基线，以便 PostgreSQL、Redis 和 RabbitMQ
  的依赖关系可以在开发和测试环境中复现。
- Flutter App MUST 保持跨平台结构，但当前正式交付基线是 Android；iOS 适配属于后续扩展，
  不得用“跨平台”替代 Android 真实验证。
- Flutter App MUST 只与 Spring Boot 后端通信，不得直接访问 PostgreSQL、Redis、
  RabbitMQ、华为云 FRS、华为云 OBS 或服务器文件系统。

## 华为云 FRS 集成约束

- 后端 MUST 定义 `FaceRecognitionProvider` 接口，并提供
  `HuaweiCloudFrsFaceRecognitionProvider` 作为第一版生产实现。
- 业务模块 MUST 只依赖 `FaceRecognitionProvider`，不得散落直接调用华为云 FRS SDK
  或 REST API。
- 华为云 FRS 敏感配置，包括 `AK`、`SK`、`ProjectId`、`Region`、`Endpoint`、
  `FaceSetName` 等，MUST 通过环境变量或安全配置方式注入，MUST NOT 硬编码。
- 人脸照片入库流程 MUST 为：
  `上传照片 -> 校验文件与五张上限 -> PostgreSQL 保存照片元数据(PENDING) -> RabbitMQ 投递入库任务 ->
  Worker 调用华为云 FRS 添加人脸 -> PostgreSQL 保存 externalFaceId/faceSetName ->
  更新照片状态为 ENROLLED 或 FAILED`。
- 签到识别流程 MUST 为：
  `扫码进入场次 -> 上传签到照片 -> 校验 session -> Redis 限流和幂等控制 ->
  PostgreSQL 创建 sign_in_attempt -> 第一阶段同步调用华为云 FRS 检测和人脸搜索 ->
  对候选结果执行人脸比对确认 -> 根据 similarity 与业务阈值判定结果 ->
  PostgreSQL 生成签到记录或异常记录 ->
  返回最终结果或在需要时返回 `PROCESSING` 结果供前端查询`。
- 华为云 FRS 调用失败、超时、限流或异常返回时，系统 MUST 记录可追踪日志和调用审计，
  并生成可查询的失败或人工复核结果。

## 华为云 OBS 集成约束

- 后端 MUST 通过受控存储服务统一封装华为云 OBS 的上传、删除、临时访问 URL 和对象路径管理。
- Flutter App MUST NOT 直接持有 OBS 凭证、直接访问 OBS 对象或绕过后端上传图片。
- PostgreSQL MUST 持久化与 OBS 对象关联的 `bucket`、`region`、`objectKey`、
  `contentType`、`sizeBytes`、`sha256` 和 `storageProvider` 元数据。
- 如前端需要查看图片，后端 MUST 生成临时访问 URL 或提供代理访问，MUST NOT 默认暴露长期公开 URL。

## 开发流程与质量门禁

- 所有非琐碎需求变更 MUST 先经过 `spec`、`plan` 和 `tasks` 流程，再进入实现。
- `spec` MUST 明确角色与权限边界、用户名唯一规则、场次与二维码规则、图片上传规则、华为云 FRS 与 OBS 接入方式、
  人脸库与外部引用关系、签到流程、异常场景、验收标准和数据边界。
- `plan` MUST 明确单体模块归属、`FaceRecognitionProvider` 放置位置、华为云 FRS
  鉴权配置、数据库与迁移策略、Redis 与 RabbitMQ 用法、重试策略、人工复核策略、测试策略、
  Android 验证策略和任何安全例外。
- `tasks` MUST 覆盖鉴权、角色权限、场次与二维码、人脸照片管理、华为云 FRS Provider、
  FRS SDK 或 REST Client 封装、Mock Provider、异步入库、签到识别、用户管理、用户名唯一性、
  五张照片上限双端拦截、异常处理、审计日志、限流、幂等、防重复提交、唯一约束、重试、死信，
  以及 Testcontainers 或设备验证等必要
  工作项；若某项不适用，必须显式说明原因。
- 代码评审 MUST 拒绝以下变更：未备案的微服务拆分、未备案的 FRS 或 OBS 替换、前端直连
  PostgreSQL、Redis、RabbitMQ、华为云 FRS、华为云 OBS 或服务器文件系统、用 Redis
  或 RabbitMQ 充当事实源、缺失管理员审计、绕过签到校验、绕过文件上传限制、绕过
  `FaceRecognitionProvider` 抽象、或跳过规定的自动化测试与 Android 验证。
- 任何偏离本宪法的实现方案 MUST 在同一改动中更新宪法、模板和受影响文档，并附带迁移说明。

## Governance

- 本宪法高于 README、任务示例和局部实现习惯；若出现冲突，以本宪法为准。
- 宪法修订 MUST 与相关模板及运行文档同步提交，并在评审说明中标明影响范围。
- 版本号遵循语义化版本规则：破坏性原则调整使用 MAJOR，新增原则或实质性扩展使用 MINOR，
  纯澄清与文字修正使用 PATCH。
- 每个 `spec`、`plan`、`tasks` 和代码评审都 MUST 执行一次宪法符合性检查，并记录任何
  例外及其理由。
- 以下变更 MUST 先修订本宪法，再推进下游文档与实现：更换核心技术栈、替换华为云 FRS、
  改为本地人脸识别模型、改为自建远程识别服务、拆分微服务、改变 PostgreSQL 唯一事实源
  原则、改变 Redis 或 RabbitMQ 的职责边界、改变扫码免登录签到规则、改变角色权限模型、
  改变用户名唯一标识规则，或改变重复签到判定规则。

**Version**: 1.3.0 | **Ratified**: 2026-05-08 | **Last Amended**: 2026-05-09
