---
order: 20
title: 项目、堆栈与状态管理
group: 第 1 篇：Get Started & 架构基石
---

# 项目、堆栈与状态管理

## 本章定位

本章解释 Pulumi Project、Stack、Config 与 State Backend 如何共同构成生产级交付边界。

## 官方映射

- 计划映射：`content/docs/iac/concepts/projects/`、`content/docs/iac/concepts/stacks/`、`content/docs/iac/concepts/state-and-backends/`
- 当前等价路径：`content/docs/iac/concepts/projects/`、`content/docs/iac/concepts/stacks.md`、`content/docs/iac/concepts/state-and-backends.md`、`content/docs/iac/concepts/config.md`

## 完成版目录

2.1 Project 是什么：`Pulumi.yaml`、Runtime、Main、Backend 与插件约定  
2.2 Stack 是什么：环境、区域、租户与生命周期边界  
2.3 配置系统：明文配置、加密配置、命名空间与跨栈配置  
2.4 状态文件结构：资源快照、URN、依赖边、Outputs 与 Secrets  
2.5 Pulumi Cloud 后端：并发锁、历史记录、审计与组织协作  
2.6 自托管后端：S3、Azure Blob、GCS、本地文件系统的取舍  
2.7 状态迁移与恢复：导出、导入、备份、灾难恢复演练  
2.8 本章实验：创建多堆栈并切换本地后端

## 动手实验

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-projects-stacks-state" title="实验：Projects、Stacks 与本地状态" desc="创建 dev 与 prod 两个堆栈，设置配置项，导出并检查本地状态文件。" />

## 本章交付物

- Project/Stack/State 关系图。
- Pulumi Cloud 后端与自托管后端对比表。
- 多堆栈配置示例。
- 状态迁移与事故恢复清单。