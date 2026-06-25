# 测试驱动开发与 CI/CD 实验（AWS / MiniStack）

本实验使用本地 Pulumi Backend、`@pulumi/aws` 和 MiniStack。你会先写一个失败的 mock 单元测试，再修改 S3 Bucket 的资源输入让它通过，随后用 Automation API 部署到 MiniStack，并生成可用 act 本地模拟的 GitHub Actions 预览工作流。