---
order: 1
title: 课程介绍
group: 起步
---

# 课程介绍

欢迎来到 **Pulumi 架构师之路：交互式教程**。

本教程面向已经具备基础云计算经验、希望系统掌握 Pulumi 的工程师。它不是零散 API 说明，而是把 Pulumi 官方 IaC 文档体系重新组织成一条架构师成长路径：先理解引擎与状态，再掌握资源与数据流，最后进入组件化、多环境工程化、Automation API、包分发、策略检查、故障排查和 CI/CD。

## 教程范围：仅覆盖 Pulumi OSS

本教程只讨论可以通过 Pulumi OSS 工具链独立完成的 IaC 能力，包括 Pulumi CLI、各语言 SDK、资源 Provider、Automation API、本地或自管理 Backend、本地 Policy Pack 与通用 CI/CD 系统。

必须搭配 Pulumi Cloud 才能使用或完整运行的能力，不纳入本教程范围，例如托管组织与控制台、Pulumi ESC、Pulumi Deployments、云端策略托管、云端审计与托管协作功能。后续章节引用官方文档时，也会优先筛选其中可在 OSS 工具链下独立实践的部分。

## 你将学到

- Pulumi 与传统声明式 IaC 的范式差异。
- Project、Stack、Config、State 与 Backend 的生产语义。
- `Input<T>`、`Output<T>`、Secrets、资源依赖和生命周期选项。
- 使用 `ComponentResource` 封装企业级基础设施组件。
- 使用 Asset 与 Archive 把文件、目录和代码包交给资源输入。
- 使用多环境 Stack 配置组织 dev、staging、prod 等环境差异。
- 使用 Automation API 构建自助式平台工程后端。
- 使用 Pulumi Packages 分发可复用基础设施能力。
- 使用 Policy as Code 在本地和 CI 中运行策略检查。
- 使用日志、诊断、状态导出与 refresh 排查 Pulumi 部署问题。
- 使用 Mock、Preview、CI/CD 与策略检查构建安全交付流水线。

## 实验环境

每个实战章节都会连接到 Killercoda 场景。实验环境默认提供：

| 工具 | 用途 |
|------|------|
| Pulumi CLI | 执行 `preview`、`up`、`destroy` 等核心工作流 |
| Node.js / npm | 运行 TypeScript 示例项目 |
| 本地 Pulumi 后端 | 无需 Pulumi Cloud 账号即可完成基础实验 |
| `@pulumi/random` | 用无云账号依赖的 Provider 演示资源生命周期 |

大部分课程会提供 AWS 与 Azure 两套动手实验。两套实验的教学目标和操作路径基本等价，差别主要在资源名称、Provider 与本地模拟器。学习时不需要两套都完成；可以根据自己更熟悉的云平台或后续工作需要选择其中一套。

后续需要真实云资源的章节，会单独说明凭据、权限和清理方式。



## 全书目录

### 第 1 篇：Get Started

- [IaC 范式转移与 Pulumi 架构解析](architecture.md)
- [Pulumi 是如何工作的](how-pulumi-works.md)
- [如何安装 Pulumi](install.md)

### 第 2 篇：Concepts 深度剖析

- [项目、堆栈与状态管理](projects-stacks-state.md)
- [Stack 详解](stacks.md)
- [State 与 Backend](state_backends.md)
- [Provider 抽象](providers.md)
- [资源](resources.md)
- [Inputs, Outputs](inputs-outputs.md)
- [Secrets 机密处理](secrets-handling.md)
- [Stash 状态暂存](stash.md)
- [Functions 函数](functions.md)
- [Assets 与 Archives](assets_archives.md)
- [企业级架构：Components](components.md)
- [Configuration 配置](configs.md)

### 第 3 篇：Pulumi OSS 工程化扩展与交付实践

- [多环境 Stack 配置与动态基础设施](dynamic-stacks.md)
- [Automation API](automation-api.md)
- [Pulumi Packages](packages.md)
- [Policy as Code](policy-as-code.md)
- [Pulumi 调试与故障排查](debugging.md)
- [测试驱动开发与 CI/CD 实践](testing.md)
- [最佳实践](best-practices.md)

### 附录

- [附录与速查表](appendix.md)

## 官方目录对齐说明

本书以 Pulumi 官方 `content/docs/iac` 当前目录为参照。原写作计划中提到的 `automation-api` 与 `packages-and-automation` 在当前官方树中可通过 `concepts/automation-api.md`、`concepts/packages/`、Policy as Code 相关文档、`guides/building-extending/`、`guides/testing/` 等路径建立等价映射。本教程聚焦 Pulumi OSS：实验默认使用 Pulumi CLI、Automation API、本地或自管理 Backend、本地 Policy Pack 与通用 CI 系统，不安排依赖 Pulumi Cloud 的 ESC、Deployments 或云端策略托管能力。

## 仓库结构

```text
docs/             VitePress 电子书章节
pulumi-tutorial/  Killercoda 动手实验场景
scripts/          侧边栏与实验脚本同步工具
```