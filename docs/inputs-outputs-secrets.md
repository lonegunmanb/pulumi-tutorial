---
order: 40
title: Inputs, Outputs & Secrets
group: 第 2 篇：Concepts 深度剖析
---

# Inputs, Outputs & Secrets

## 本章定位

本章解决 Pulumi 学习曲线中最关键的问题：异步输出、依赖追踪与机密数据如何在状态图中安全流动。

## 官方映射

- 计划映射：`content/docs/iac/concepts/inputs-outputs/`、`content/docs/iac/concepts/secrets/`
- 当前等价路径：`content/docs/iac/concepts/inputs-outputs/`、`content/docs/iac/concepts/secrets/`、`content/docs/iac/concepts/resources/options/additionalsecretoutputs.md`

## 完成版目录

4.1 Pulumi 的异步编程模型：为什么资源属性不是普通字符串  
4.2 `Input<T>` 与 `Output<T>`：类型系统、依赖追踪与序列化边界  
4.3 `apply` 的正确使用：转换、拼接、条件逻辑与副作用禁区  
4.4 多输出组合：`all`、结构化输出与跨资源数据编排  
4.5 Invokes 与 Functions：直接形式、输出形式与依赖感知调用  
4.6 Secrets 是一等公民：加密、解密、状态落盘与访问边界  
4.7 污染追踪：派生变量如何自动保持加密属性  
4.8 `additionalSecretOutputs`：强制加密 Provider 未标注的敏感输出  
4.9 本章实验：构建带密码、连接串和下游依赖的服务

## 动手实验

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-inputs-outputs-secrets" title="实验：Output 与 Secret 数据流" desc="使用随机密码资源演示 apply、all、secret 与派生输出的加密传播。" />

## 本章交付物

- `Input<T>`/`Output<T>` 数据流图。
- `apply` 正反例对照。
- Secrets 污染追踪示意图。
- 加密输出与连接串实战。