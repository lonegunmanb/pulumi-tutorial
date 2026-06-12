---
order: 50
title: 企业级架构：Components
group: 第 2 篇：Concepts 深度剖析
---

# 企业级架构：Components

## 本章定位

本章把资源原语上升为架构抽象，讲解如何用 `ComponentResource` 构建可复用、可测试、可演进的企业级基础设施组件。

## 官方映射

- 计划映射：`content/docs/iac/concepts/components/`
- 当前等价路径：`content/docs/iac/concepts/components/`

## 完成版目录

5.1 为什么需要组件：从平铺资源到架构级抽象  
5.2 面向对象的基础设施：继承 `ComponentResource` 并定义强类型入参  
5.3 组件边界设计：职责、命名、父子关系与可替换性  
5.4 封装 VPC/子网/路由表：把云原语组合成领域对象  
5.5 `registerOutputs()` 的语义：合成输出、完成信号与状态图一致性  
5.6 组件版本演进：兼容性、弃用字段、别名与迁移指南  
5.7 组件测试策略：Mock、断言、快照与契约测试  
5.8 本章实验：实现一个可复用组件并在多堆栈复用

## 动手实验

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-components" title="实验：封装 ComponentResource" desc="把多个随机资源封装为一个组件，观察父子关系、输出注册和状态图变化。" />

## 本章交付物

- ComponentResource 生命周期图。
- 可复用组件完整代码。
- `registerOutputs()` 行为说明。
- 组件演进与迁移清单。