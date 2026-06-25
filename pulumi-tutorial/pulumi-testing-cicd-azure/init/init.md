# 测试驱动开发与 CI/CD 实验（Azure / miniblue）

本实验使用本地 Pulumi Backend、`@pulumi/azure` 和 miniblue。你会先写一个失败的 mock 单元测试，再修改 Resource Group 与 Virtual Network 的资源输入让它通过，随后用 Automation API 部署到 miniblue，并生成可用 act 本地模拟的 GitHub Actions 预览工作流。
