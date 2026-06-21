---
order: 70
title: Pulumi Packages
group: 第 3 篇：Pulumi OSS 工程化扩展与交付实践
---

# Pulumi Packages

## 本章定位

本章讲解如何把可复用基础设施能力打包成 Pulumi Package，使组件能力可以通过语言 SDK 分发给不同项目和团队使用。本章聚焦组件包化、Schema、SDK 生成、版本管理与发布流程。

## 官方映射

- 计划映射：`content/docs/iac/packages-and-automation/`。
- 当前等价路径：`content/docs/iac/concepts/packages/`、`content/docs/iac/guides/building-extending/`、`content/docs/iac/concepts/plugins.md`。

## 完成版目录

8.1 Pulumi Package 解决的问题：从本地组件到跨项目分发  
8.2 Package 基本结构：Schema、语言 SDK、插件元数据与示例项目  
8.3 组件包化：把 ComponentResource 封装成可发布能力  
8.4 多语言 SDK 生成：TypeScript、Python、Go、C# 的使用边界  
8.5 插件安装与发现：本地开发、版本命名与依赖约束  
8.6 版本演进：破坏性变更、弃用字段与迁移说明  
8.7 内部发布流程：npm/PyPI/NuGet/GitHub Releases 与制品归档  
8.8 本章实验：发布一个内部组件包骨架并在另一个项目中引用

## 动手实验

本章实验将从已有 ComponentResource 出发，补齐 Package 所需的 schema 与语言包骨架，演示一个最小可复用组件包的开发流程。

## 本章交付物

- Pulumi Package 生命周期图。
- 组件包化示例。
- 多语言 SDK 生成流程。
- Package 版本发布检查清单。