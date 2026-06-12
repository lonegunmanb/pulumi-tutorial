---
order: 70
title: Packages 与 CrossGuard
group: 第 3 篇：Automation API, Packages & Guides
---

# Packages 与 CrossGuard

## 本章定位

本章讲解如何把组件、Provider 与策略治理产品化，使 Pulumi 成为组织级平台能力的扩展底座。

## 官方映射

- 计划映射：`content/docs/iac/packages-and-automation/`
- 当前等价路径：`content/docs/iac/concepts/packages/`、`content/docs/iac/guides/building-extending/`、`content/docs/iac/concepts/plugins.md`

## 完成版目录

7.1 Pulumi Packages：Schema、SDK 生成与多语言分发  
7.2 组件包化：从内部组件库到组织级平台产品  
7.3 Dynamic Providers：自定义资源的 Create/Read/Update/Delete 生命周期  
7.4 Provider 插件与可执行插件：何时该写 Provider，何时只写 Component  
7.5 CrossGuard 规则模型：Policy Pack、验证时机与组织策略  
7.6 Preview 阶段拦截：阻断开放 0.0.0.0/0、未加密存储与缺失标签  
7.7 策略分层：开发提示、强制阻断、例外审批与审计报告  
7.8 本章实验：发布一个内部组件包并用策略禁止公网数据库

## 动手实验

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-packages-crossguard" title="实验：策略即代码与组件包骨架" desc="创建 Policy Pack 骨架，编写资源命名和标签策略，并观察预览阶段的阻断效果。" />

## 本章交付物

- Pulumi Package 生命周期图。
- Dynamic Provider 示例。
- CrossGuard Policy Pack 示例。
- 组织级合规策略清单。