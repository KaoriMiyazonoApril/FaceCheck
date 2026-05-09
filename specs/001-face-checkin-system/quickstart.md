# Quickstart: 管理员场次人脸签到系统

## 1. Prerequisites

- Java 21
- Flutter stable + Dart 3.x
- Docker Desktop 或等价 Docker 环境
- Android Studio 或可用 Android 模拟器 / 真机
- 可选：华为云 FRS 与 OBS 凭证

## 2. Environment Variables

Backend runtime 至少需要以下配置：

```bash
APP_PROFILE=local

DB_URL=jdbc:postgresql://localhost:5432/facecheck
DB_USERNAME=facecheck
DB_PASSWORD=facecheck

REDIS_HOST=localhost
REDIS_PORT=6379

RABBITMQ_HOST=localhost
RABBITMQ_PORT=5672
RABBITMQ_USERNAME=guest
RABBITMQ_PASSWORD=guest

JWT_SECRET=replace-with-long-random-secret
JWT_EXPIRES_MINUTES=120

FACE_PROVIDER_MODE=mock            # mock | huawei
FRS_AK=
FRS_SK=
FRS_PROJECT_ID=
FRS_REGION=
FRS_ENDPOINT=
FRS_FACE_SET_NAME=facecheck-default
FRS_SIMILARITY_THRESHOLD=85
FRS_LIVENESS_ENABLED=false

OBS_AK=
OBS_SK=
OBS_ENDPOINT=
OBS_REGION=
OBS_BUCKET=
```

Notes:

- `FACE_PROVIDER_MODE=mock` 时，业务流可在无真实 FRS 凭证下跑通。
- 若未提供真实 OBS 凭证，图片上传相关自动化测试应使用 test profile 或 mock storage bean。
- 华为云凭证只存在后端环境中，Flutter App 不读取这些值。

## 3. Start Local Infrastructure

```bash
docker compose up -d postgres redis rabbitmq
```

建议 compose 服务名：

- `postgres`
- `redis`
- `rabbitmq`

## 4. Bootstrap Backend

1. 创建 Spring Boot 单体骨架并接入：
   - Spring Web
   - Spring Security
   - Spring Data JPA
   - Spring Validation
   - PostgreSQL
   - Spring Data Redis
   - Spring AMQP
   - Flyway
2. 实现 Flyway 初始迁移，覆盖：
   - `user`
   - `person`
   - `face_photo`
   - `huawei_face_ref`
   - `attendance_session`
   - `attendance_checkin_attempt`
   - `attendance_record`
   - `audit_log`
   - `system_config`
   - `external_service_call_log`
3. 配置默认本地 profile：
   - `MockFaceProvider`
   - Testcontainers 或 test-profile 替身用于自动化测试

## 5. Bootstrap Flutter App

1. 创建 Flutter 工程并接入：
   - `dio`
   - `flutter_riverpod`
   - `go_router`
   - `flutter_secure_storage`
   - `camera`
   - `mobile_scanner`
2. 首批页面：
   - 登录页
   - 首页
   - 个人信息页
   - 人脸照片管理页
   - 扫码页
   - 场次确认页
   - 拍照签到页
   - 签到结果页
   - 个人签到记录页
   - 管理员场次管理页
   - 管理员创建/编辑场次页
   - 管理员二维码展示页
   - 管理员场次签到记录页
   - 管理员全局签到记录页
   - 异常签到处理页

## 6. Recommended Build Order

1. 完成 Flyway 模型和基础安全框架
2. 完成 `auth` + `identity`
3. 完成 `storage` + `face` 的上传与异步注册链路
4. 完成 `session` 的场次和二维码管理
5. 完成 `checkin` 的免登录签到主链路
6. 完成 `admin` 的记录、异常和配置页面
7. 补齐 Android 验证和容器化测试

## 7. Verification Checklist

### Backend automated

- 用户认证测试通过
- 管理员权限测试通过
- 人员管理测试通过
- 图片上传测试通过
- OBS 适配器测试通过
- FRS Provider / Client 测试通过
- 照片异步注册任务测试通过
- 场次管理测试通过
- 扫码签到流程测试通过
- 限流、幂等、防重复签到测试通过
- PostgreSQL / Redis / RabbitMQ Testcontainers 测试通过

### Android validation

- 登录状态恢复
- 相机权限申请
- 扫码解析场次
- 场次确认页展示
- 拍照、预览、上传
- 未登录扫码签到闭环
- 成功 / 失败 / 已签到 / 处理中结果页
- Token 本地安全存储与失效处理

## 8. Optional Cloud-backed Manual Validation

当提供真实华为云凭证后，可执行一轮云端验证：

1. 使用真实 OBS 上传用户照片与签到照片
2. 使用真实 FRS 完成人脸检测、AddFaces、SearchFace
3. 验证 `frsFaceId`、`externalImageId` 和 `externalFields` 已写入 PostgreSQL
4. 验证超时、限流和失败分支能形成可查询 attempt / 异常记录
