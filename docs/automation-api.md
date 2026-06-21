---
order: 60
title: Automation API
group: 第 3 篇：Pulumi OSS 工程化扩展与交付实践
---

# Automation API

## 本章定位

本章把 Pulumi 从 CLI 工作流推进到可编程平台工程，演示如何用 SDK 直接管理工作区、堆栈、预览、部署与销毁。

## 官方映射

- 计划映射：`content/docs/iac/automation-api/`
- 当前等价路径：`content/docs/iac/concepts/automation-api.md`、`content/docs/iac/guides/building-extending/`

## 完成版目录

- 7.1 从 CLI 到 SDK：Automation API 解决的核心问题
- 7.2 Workspace 模型：LocalWorkspace、ProjectSettings、StackSettings 与依赖安装
- 7.3 Stack 操作编排：`selectStack`、`up`、`preview`、`refresh`、`destroy`
- 7.4 构建平台后端：用 Express.js/FastAPI 暴露环境申请 API
- 7.5 Inline Programs：在内存闭包中动态组装架构
- 7.6 事件流与可观测性：捕获日志、资源事件、诊断与进度
- 7.7 配置与机密注入：StackSettings、环境变量与本地 secrets provider
- 7.8 安全模型：租户隔离、凭据边界、并发锁与超时回收
- 7.9 本章实验：实现一个“临时测试环境即服务”的后端

## 动手实验

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-automation-api" title="实验：用 Automation API 驱动堆栈" desc="使用 Node.js Automation API 创建本地工作区，执行 preview/up/destroy 并读取事件流。" />

## 本章交付物

- Automation API 工作流图。
- Express.js/FastAPI 平台后端示例。
- Inline Program 示例。
- 临时环境创建与销毁流程。