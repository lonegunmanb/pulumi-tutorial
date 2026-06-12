---
order: 30
title: 资源与精细控制
group: 第 2 篇：Concepts 深度剖析
---

# 资源与精细控制

## 本章定位

本章进入 Pulumi 资源模型核心，解释资源命名、依赖、生命周期、重构、导入与变更拦截等生产级控制能力。

## 官方映射

- 计划映射：`content/docs/iac/concepts/resources/`、`content/docs/iac/concepts/resources/options/aliases/`、`content/docs/iac/concepts/resources/options/transforms/`
- 当前等价路径：`content/docs/iac/concepts/resources/`、`content/docs/iac/concepts/resources/options/aliases.md`、`content/docs/iac/concepts/resources/options/transforms.md`

## 完成版目录

3.1 资源实例化与逻辑命名：URN、逻辑名、物理名与自动命名  
3.2 CustomResource、ComponentResource 与 Provider Resource 的边界  
3.3 依赖建模：隐式依赖、`dependsOn`、`parent`、`provider` 与 `providers`  
3.4 生命周期保护：`protect`、`retainOnDelete`、`deletedWith` 与删除策略  
3.5 替换控制：`deleteBeforeReplace`、`replaceOnChanges`、`replacementTriggers`  
3.6 漂移与差异处理：`ignoreChanges`、`hideDiffs`、`customTimeouts`  
3.7 资源重构的艺术：`aliases` 如何认领旧资源并避免危险 Replace  
3.8 导入既有资源：`import`、状态认领与重构路径  
3.9 动态拦截与合规：`transforms`、`transformations` 与全局标签注入  
3.10 本章实验：用别名完成零重建迁移

## 动手实验

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-resources-options" title="实验：资源选项与安全重构" desc="观察 URN，调整资源选项，并用 aliases 解释重命名资源时如何避免误重建。" />

## 本章交付物

- URN 与物理名称关系图。
- 资源选项速查表。
- `aliases` 零重建迁移示例。
- 全局标签注入 `transforms` 示例。