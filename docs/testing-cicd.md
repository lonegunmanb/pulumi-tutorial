---
order: 80
title: 测试驱动开发与 CI/CD 实践
group: 第 3 篇：Pulumi OSS 工程化扩展与交付实践
---

# 测试驱动开发与 CI/CD 实践

## 本章定位

本章把前面所有概念落到工程交付体系中，形成可测试、可审查、可回滚、可审计的 Pulumi 生产流水线。

## 官方映射

- 计划映射：`content/docs/iac/guides/testing/`
- 当前等价路径：`content/docs/iac/guides/testing/`、`content/docs/iac/guides/basics/`、`content/docs/iac/operations/`

## 完成版目录

- 11.1 基础设施测试金字塔：单元测试、集成测试、预览审查、策略测试
- 11.2 Mock API：在毫秒级测试中替代真实云端交互
- 11.3 Mocha/Jest/PyTest 实战：资源属性断言、依赖断言与输出断言
- 11.4 Preview 驱动的 Pull Request 审查：把计划变更前置到代码评审
- 11.5 GitHub Actions 集成：登录、缓存、预览、手动门禁、部署与回滚
- 11.6 GitLab CI 集成：多环境矩阵、受保护变量与手动门禁
- 11.7 企业级流水线设计：状态锁、并发控制、CI 日志归档、漂移检测与灾备
- 11.8 本地 Policy Pack 集成：在 CI 中执行策略检查
- 11.9 本章实验：构建从 PR Preview 到 main 自动交付的完整流水线

## 动手实验

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-testing-cicd" title="实验：Mock 测试与 CI 配置" desc="编写 Pulumi 单元测试，生成 GitHub Actions 预览流水线，并演示 PR Preview 的最小闭环。" />

## 本章交付物

- 基础设施测试金字塔图。
- Mock 单元测试示例。
- GitHub Actions/GitLab CI 流水线示例。
- 企业级交付检查清单。