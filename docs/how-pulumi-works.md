---
order: 12
title: Pulumi 是如何工作的
group: 第 1 篇：Get Started & 架构基石
---

# Pulumi 是如何工作的

<TutorialAcknowledgement />

> 官方参照：[How Pulumi IaC Works](https://www.pulumi.com/docs/iac/guides/basics/how-pulumi-works/)。上一章已经介绍 CLI、Language Host、Deployment Engine、Resource Provider、State Backend 与 Pulumi Cloud 的职责；本章只沿着官方示例观察一次程序运行如何变成具体资源操作。

## 本章定位

本章不是重新讲一遍 Pulumi 架构，而是回答三个更具体的问题：

- 第一次运行时，为什么两个资源都会显示 create？
- 修改一个标签后，为什么只显示 update？
- 改逻辑名或删除资源声明时，为什么会出现 create/delete？

如果你对 Engine、Provider、State、Output 或 Pulumi Cloud 的职责还不熟，先回看 [IaC 范式转移与 Pulumi 架构解析](architecture.md)。本章默认这些心智模型已经建立，只在必要处用一句话点到为止。

## 官方映射

- [Running a Pulumi program](https://www.pulumi.com/docs/iac/guides/basics/how-pulumi-works/#running-a-pulumi-program)：对应本章 1.1 至 1.4。
- [Resource operations](https://www.pulumi.com/docs/iac/guides/basics/how-pulumi-works/#resource-operations)：对应本章 1.5 与实验中的 preview 输出。
- [Creation and deletion order](https://www.pulumi.com/docs/iac/guides/basics/how-pulumi-works/#creation-and-deletion-order)：对应本章 1.6。
- [Architecture](https://www.pulumi.com/docs/iac/guides/basics/how-pulumi-works/#architecture)：已在上一章展开，本章不再重复。

## 1.1 程序先产生资源注册请求

假设有这样一段 TypeScript 程序：

```ts
import * as aws from "@pulumi/aws";

const mediaBucket = new aws.s3.Bucket("media-bucket");
const contentBucket = new aws.s3.Bucket("content-bucket");
```

本章关心的是运行时顺序，而不是再次解释各组件职责。关键观察点只有一个：执行到第一行资源构造时，Pulumi 先产生资源注册请求；真正的云端操作由后续调和流程决定。

官方文档特别强调：第一个 Bucket 的构造函数返回，并不表示 AWS 里已经创建完成；它只表示程序已经把“当前 Stack 需要这个资源”的事实交给 Pulumi。随后程序继续执行，第二个 Bucket 也会被注册。

这一点和上一章的架构图对应：程序负责表达期望状态，后续由 Engine 与 Provider 完成差异计算和实际操作。

## 1.2 第一次运行：从空 State 到两个资源

第一次运行前，先初始化一个 Stack：

```bash
pulumi stack init mystack
```

因为 mystack 是新 Stack，它的“上一次部署状态”里没有任何用户资源。接着运行：

```bash
pulumi up
```

此时 State 里没有 media-bucket，也没有 content-bucket。第一次 `pulumi up` 的重点就是观察“空 State + 两条注册请求”会产生什么计划。

结果很直接：两个资源都会显示 create。因为对 Pulumi 来说，它们是本次程序注册的新资源，而上一次状态里没有对应记录。

官方示例里两个 Bucket 没有依赖关系，所以处理它们时可以并行。你不需要在这里重新推导依赖图，只要在 preview 输出里留意：二者同属创建操作，且没有上游/下游关系。

创建完成后，State 会记录资源身份、Provider 返回的物理信息和当前属性，成为下一次运行的比较基准。逻辑名、物理名与 auto-naming 的完整解释见上一章 1.6；本章只在实验里观察它们如何出现在输出中。

## 1.3 每次 preview/up 都会重新执行程序

Pulumi 不会只在第一次部署时执行程序。每次运行 `pulumi preview` 或 `pulumi up`，程序都会重新执行一遍，并再次产生资源注册请求。

这听起来像重复做同一件事，但比较基准已经不同了：第一次运行面对的是空 State；第二次运行面对的是已经记录过两个 Bucket 的 State。

## 1.4 修改标签：同一资源变成 update

假设把 media-bucket 改成带标签：

```ts
const mediaBucket = new aws.s3.Bucket("media-bucket", {
  tags: { owner: "media-team" },
});

const contentBucket = new aws.s3.Bucket("content-bucket");
```

这一次，State 里已经有逻辑名为 media-bucket 的资源记录。Pulumi 看到的不是“又来了一个全新 Bucket”，而是“同一个资源的期望属性变了”。

Provider 知道 S3 Bucket 的标签可以原地修改，因此 Engine 会计划一次 update，而不是 delete 再 create。更新完成后，State 再次被写成最新版本。

content-bucket 没有变化，所以它的操作是 same。Pulumi 仍然会看到这条注册请求，只是比较后发现不用做任何云端变更。

## 1.5 本章只观察四类 preview 信号

完整操作符表已经在 [IaC 范式转移与 Pulumi 架构解析](architecture.md) 里列过。本章只关注官方示例和实验里会反复出现的四种情况：

| 你做的事 | preview 中通常看到 | Pulumi 读到的事实 |
|----------|-------------------|------------------|
| 第一次部署两个 Bucket | create | State 里没有这些资源 |
| 给 media-bucket 加标签 | update | 同一资源存在，但属性变化 |
| 把 content-bucket 改名为 app-bucket | create + delete | 新逻辑名未出现，旧逻辑名不再注册 |
| 从程序里删除 content-bucket | delete | State 中有记录，但本次运行没有注册 |

replace、refresh、import、read 等更完整的操作类型，会在资源、状态和导入相关章节继续展开；这里先把注意力放在这条主线：**程序本次注册了什么，State 上次记录了什么，两者之间差异是什么。**

## 1.6 改逻辑名：为什么不是 update

继续官方示例。假设把 content-bucket 改成 app-bucket：

```ts
const mediaBucket = new aws.s3.Bucket("media-bucket", {
  tags: { owner: "media-team" },
});

const appBucket = new aws.s3.Bucket("app-bucket");
```

对 Pulumi 来说，content-bucket 与 app-bucket 是两个不同的逻辑资源身份。于是 preview 会显示两件事：创建 app-bucket，删除已经不再注册的 content-bucket。

这不是一次属性 update，而是资源身份发生了变化。生产环境里如果只是想安全重命名，应该使用 aliases；本章先不展开，后面的 [资源与精细控制](resources.md) 会专门讲。

## 1.7 顺序只看两个观察点

官方页面还提到创建和删除顺序。本章只保留两个直接服务于实验观察的结论：

- 两个资源没有依赖关系时，Pulumi 可以并行处理它们。
- 某个资源在 State 中存在、但本次程序没有再注册时，程序执行结束后会安排删除。

依赖建模、Output、dependsOn、replace 顺序和 deleteBeforeReplace 都已经在上一章或后续资源章节中展开。本章实验会让你先把最基本的运行轨迹看清楚。

## 动手实验

本章实验分为 AWS 与 Azure 两个版本。两者都不需要真实云账号：AWS 版使用 MiniStack 模拟 S3，Azure 版使用 miniblue 模拟 Azure Resource Group。

你会依次观察一次 Pulumi 程序如何变成 create，如何从 State 中读回物理名与插件信息，如何把标签变化识别为 update，如何把逻辑名变化识别为 create 加 delete，以及如何在删除资源声明后让 Engine 安排 delete。

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-how-pulumi-works-aws" title="实验：Pulumi 是如何工作的（AWS / MiniStack）" desc="用 @pulumi/aws 对接 MiniStack，观察两个 S3 Bucket 的 create、update、逻辑名变更预览、删除与 State 记录。" />

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-how-pulumi-works-azure" title="实验：Pulumi 是如何工作的（Azure / miniblue）" desc="用 @pulumi/azure 对接 miniblue，观察 Resource Group 的注册、状态记录、标签更新、逻辑名变更预览与删除。" />

## 本章小结

读完本章并完成实验后，你应该能把一次 preview/up 看成一条很具体的执行轨迹：程序重新运行，资源重新注册，Pulumi 拿本次注册结果与上次 State 比较，然后给出 create、update 或 delete。

更抽象的架构角色和生产检查清单，已经放在上一章；本章的价值在于让你能读懂一次具体变更为什么会产生这样的 preview 输出。
