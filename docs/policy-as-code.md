---
order: 75
title: Policy as Code
group: 第 3 篇：Pulumi OSS 工程化扩展与交付实践
---

# Policy as Code

## 本章定位

本章讲解 Pulumi 的策略即代码能力。这个功能早期称为 CrossGuard，后续在 Pulumi 文档与产品叙述中更多以 Policy as Code 或 Pulumi Policies 出现。本教程只使用 Pulumi OSS 可运行的本地 Policy Pack，并通过 CLI 与 CI 系统执行策略检查。

## 官方映射

- 计划映射：`Advanced Pulumi Techniques` 与 Pulumi Policy as Code 相关文档。
- 当前等价路径：Pulumi Policy as Code、Policy Pack、`pulumi preview`、`pulumi up` 与 CI 集成相关文档。

## 完成版目录

9.1 从 CrossGuard 到 Policy as Code：名称变化与能力边界  
9.2 Policy Pack 模型：规则、强制级别、资源属性与诊断信息  
9.3 本地运行策略：`pulumi preview --policy-pack` 与 `pulumi up --policy-pack`  
9.4 常见策略：命名规范、必需标签、禁止公网暴露、存储加密  
9.5 策略测试：用单元测试验证规则命中与放行条件  
9.6 CI 中强制检查：Pull Request、流水线日志与制品归档  
9.7 策略演进：从提示性规则到阻断性规则  
9.8 本章实验：编写本地 Policy Pack 并阻断不合规资源

## 动手实验

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-packages-crossguard" title="实验：本地 Policy Pack 策略检查" desc="创建 Policy Pack 骨架，编写资源命名和标签策略，并在 preview 阶段观察本地策略检查结果。" />

## 本章交付物

- Policy as Code 工作流图。
- 本地 Policy Pack 示例。
- 策略测试示例。
- CI 策略检查清单。