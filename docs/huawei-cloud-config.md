# 华为云配置说明

## 1. 本地默认模式

本地默认使用：

- `HUAWEI_CLOUD_ENABLED=false`
- `MockFaceRecognitionProvider`
- 后端受控边界，不向 Flutter App 暴露任何 AK/SK

这意味着：

- 本地联调、自动化测试、Android smoke 不依赖真实华为云账号
- 真实华为云验证应在功能完成后做少量人工核验

## 2. 环境变量

参考仓库根目录的 [.env.example](/mnt/c/Users/alvinding/desktop/FaceCheck/.env.example:1)。

关键变量：

```text
HUAWEI_CLOUD_ENABLED=true
FRS_AK=<your-ak>
FRS_SK=<your-sk>
FRS_PROJECT_ID=<your-project-id>
FRS_REGION=<your-region>
FRS_ENDPOINT=<your-frs-endpoint>
FRS_FACE_SET_NAME=facecheck-default
FRS_SIMILARITY_THRESHOLD=85

OBS_ENDPOINT=<your-obs-endpoint>
OBS_REGION=<your-obs-region>
OBS_BUCKET=<your-obs-bucket>
```

不要把真实 AK/SK、JWT_SECRET、数据库密码写进 git 跟踪文件。

## 3. 安全边界

- Flutter App 只访问 Spring Boot 后端 API
- Flutter App 不直接访问 FRS、OBS、PostgreSQL、Redis、RabbitMQ 或文件系统
- 华为云凭证只放在后端运行环境中

## 4. 建议的真实验证范围

只做小范围人工验证，不把真实云依赖当默认自动化门禁：

1. 上传 1 张普通用户照片，确认可进入 `ACTIVE`
2. 用管理员创建 1 个已发布场次
3. 用匿名签到链路提交 1 次真实照片
4. 确认 PostgreSQL 中保留 `faceSetName`、`frsFaceId`、`externalRequestId` 等外部引用
5. 确认系统状态页可看到 FRS / OBS 健康摘要

## 5. 常见注意事项

- 若只做本地 UI / API / Android smoke，不要开启 `HUAWEI_CLOUD_ENABLED=true`
- 若真实 FRS 限流或超时，应该得到可追踪失败或人工复核结果，不能静默丢请求
- OBS 只存对象，不是业务事实源；业务事实源仍然是 PostgreSQL
