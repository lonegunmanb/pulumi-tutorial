---
order: 1
title: 课程介绍
group: 起步
---

# 课程介绍

欢迎来到 **Pulumi 架构师之路：交互式教程**。

本教程面向已经具备基础云计算经验、希望系统掌握 Pulumi 的工程师。它不是零散 API 说明，而是把 Pulumi 官方 IaC 文档体系重新组织成一条架构师成长路径：先理解引擎与状态，再掌握资源与数据流，最后进入组件化、Automation API、包分发、策略治理和 CI/CD。

## 你将学到

- Pulumi 与传统声明式 IaC 的范式差异。
- Project、Stack、Config、State 与 Backend 的生产语义。
- `Input<T>`、`Output<T>`、Secrets、资源依赖和生命周期选项。
- 使用 `ComponentResource` 封装企业级基础设施组件。
- 使用 Automation API 构建自助式平台工程后端。
- 使用 Packages、Dynamic Providers 与 CrossGuard 扩展组织级能力。
- 使用 Mock、Preview、CI/CD 与策略检查构建安全交付流水线。

## 实验环境

每个实战章节都会连接到 Killercoda 场景。实验环境默认提供：

| 工具 | 用途 |
|------|------|
| Pulumi CLI | 执行 `preview`、`up`、`destroy` 等核心工作流 |
| Node.js / npm | 运行 TypeScript 示例项目 |
| 本地 Pulumi 后端 | 无需 Pulumi Cloud 账号即可完成基础实验 |
| `@pulumi/random` | 用无云账号依赖的 Provider 演示资源生命周期 |

后续需要真实云资源的章节，会单独说明凭据、权限和清理方式。

## 全书目录

### 第 1 篇：Get Started

- [IaC 范式转移与 Pulumi 架构解析](architecture.md)
- [如何安装 Pulumi](install.md)
- [项目、堆栈与状态管理](projects-stacks-state.md)

### 第 2 篇：Concepts 深度剖析

- [资源与精细控制](resources.md)
- [Inputs, Outputs & Secrets](inputs-outputs-secrets.md)
- [企业级架构：Components](components.md)

### 第 3 篇：Automation API, Packages & Guides

- [Automation API](automation-api.md)
- [Packages 与 CrossGuard](packages-crossguard.md)
- [测试驱动开发与 CI/CD 实践](testing-cicd.md)

### 附录

- [附录与速查表](appendix.md)

## 官方目录对齐说明

本书以 Pulumi 官方 `content/docs/iac` 当前目录为参照。原写作计划中提到的 `automation-api` 与 `packages-and-automation` 在当前官方树中可通过 `concepts/automation-api.md`、`concepts/packages/`、`guides/building-extending/`、`guides/testing/` 等路径建立等价映射。

## 仓库结构

```text
docs/             VitePress 电子书章节
pulumi-tutorial/  Killercoda 动手实验场景
scripts/          侧边栏与实验脚本同步工具
```