---
order: 78
title: Pulumi 调试与故障排查
group: 第 3 篇：Pulumi OSS 工程化扩展与交付实践
---

# Pulumi 调试与故障排查

## 本章定位

本章讲解如何在不依赖 Pulumi Cloud 的前提下排查 Pulumi 项目的常见问题。重点覆盖配置错误、部署失败、资源依赖、日志诊断、状态检查、漂移识别与 CI 日志定位。

## 官方映射

- 计划映射：`Debugging Infrastructure with Pulumi`。
- 当前等价路径：`content/docs/iac/cli/`、`content/docs/iac/concepts/state/`、`content/docs/iac/operations/`、`content/docs/iac/troubleshooting/`。

## 完成版目录

10.1 Pulumi 故障排查地图：配置、代码、Provider、状态与真实云资源  
10.2 配置错误：缺失配置、命名空间、类型转换与 Secrets 解密问题  
10.3 部署失败：权限不足、资源已存在、配额限制与 Provider 返回错误  
10.4 依赖问题：父子资源、`dependsOn`、Output 链路与隐式依赖  
10.5 日志与诊断：preview/up 输出、详细日志、诊断消息与事件流  
10.6 状态排查：`pulumi stack`、`pulumi stack export`、备份与恢复  
10.7 漂移与修复：`pulumi refresh`、重新导入、手工变更后的处理策略  
10.8 CI 中定位失败：流水线日志、退出码、制品归档与最小复现  
10.9 本章实验：从一次失败的更新中定位配置、依赖与状态问题

## 动手实验

本章实验将构造几个常见失败场景，让学习者通过 preview、up、refresh、stack export 与 CI 日志逐步定位问题来源。

## 本章交付物

- Pulumi 故障分类表。
- 常见错误排查流程图。
- 状态导出与恢复检查清单。
- CI 故障定位清单。