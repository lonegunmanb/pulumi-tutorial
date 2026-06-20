---
order: 46
title: Stash 状态暂存
group: 第 2 篇：Concepts 深度剖析
---

# Stash 状态暂存

## 本章定位

::: tip 导言
有些值不是用户配置，也不是某个云资源天然返回的属性，而是在部署时由程序计算出来的。第一次部署的人是谁、第一次部署的时间是什么、一次随机生成但以后必须保持稳定的值是什么——这些信息都需要被 Pulumi 记住。**Stash** 就是为这类需求准备的内置资源：它把一个值保存进当前 Stack 的 state，并在后续部署中继续返回最初保存的值。
:::

上一章我们讲了 Secret：它回答的是“敏感值如何安全地进入配置、程序和 state”。Stash 回答的是另一个问题：**某个计算值如果需要跨多次部署保持不变，应该由谁来记住？**

初学者可以先把 Stash 理解成 state 账本里的一张“归档单”。程序每次运行都会递交一份新的 input，但这张归档单的 output 默认仍然保留第一次归档时的内容。只有当你明确替换这个 Stash 资源时，保存值才会更新。

本章回答以下问题：

- Stash 与 Config、Stack Output、普通资源输出有什么区别？
- `input` 与 `output` 分别表示什么，为什么修改 input 不会自动改写 output？
- 如何保存对象、数组等复杂值？
- Stash 保存 secret 时，是否仍然会加密？
- 如果确实要刷新保存值，应该怎样替换 Stash？
- 删除 Stash 时，state 中的保存值会发生什么？

## 官方映射

- [Stash](https://www.pulumi.com/docs/iac/concepts/stash/)：Stash 的核心语义、复杂值、secret、更新、删除与常见用途。
- [Targeted updates](https://www.pulumi.com/docs/iac/operations/stack-management/targeted-updates/#replacing-a-single-resource)：用 `--target-replace` 替换单个资源。
- [pulumi state taint](https://www.pulumi.com/docs/iac/cli/commands/pulumi_state_taint/)：把资源标记为下一次部署需要替换。
- [replacementTrigger](https://www.pulumi.com/docs/iac/concepts/resources/options/replacementtrigger/)：用资源选项按任意触发值控制替换。
- [Introducing the Stash Resource](https://www.pulumi.com/blog/introducing-stash-resource/)：Stash 的发布说明与版本要求。

> Stash 是 Pulumi 内置资源，不需要 AWS、Azure、Kubernetes 等云 provider。若项目里的 Pulumi SDK 或 CLI 较旧，请升级到支持 Stash 的版本；官方发布说明把它列为 Pulumi v3.208.0 及以后版本提供的能力。

## 为什么需要 Stash

先把几个容易混淆的概念分开：

| 概念 | 谁提供值 | 主要用途 | 会不会自动跨部署保持第一次的值 |
| --- | --- | --- | --- |
| Config | 操作者或流水线 | 给当前 Stack 提供环境参数 | 不会，配置改了就是新值 |
| 普通资源输出 | Provider 或引擎 | 描述资源创建后的属性 | 由资源自身生命周期决定 |
| Stack Output | 程序顶层导出 | 把值公开给 CLI 或其他 Stack | 不会，只是导出当前程序结果 |
| Stash | Pulumi 内置资源 | 把任意值保存进 state | 会，除非替换 Stash 资源 |

因此，Stash 适合记录“第一次算出来以后要保持稳定”的值。例如：

- 首次执行部署的用户。
- Stack 第一次创建的时间。
- 首次生成、之后应保持不变的随机值。
- 某个外部系统返回的初始化令牌。
- 程序运行过程中算出的中间结果，需要下一次部署继续引用。

它不适合替代 Config。如果一个值本来就应该由环境配置控制，例如区域、实例规格、开关、配额，就应该继续使用 Config。Stash 也不是通用数据库；它保存的是 Pulumi state 的一部分，生命周期应该和当前 Stack 的基础设施定义绑定在一起。

## 核心模型：input 与 output

在 TypeScript 中创建 Stash 的写法很直接：

```ts
import * as pulumi from "@pulumi/pulumi";
import * as os from "node:os";

const firstDeployer = new pulumi.Stash("firstDeployer", {
    input: os.userInfo().username,
});

export const originalDeployer = firstDeployer.output;
export const currentDeployer = firstDeployer.input;
```

这里最重要的是两个属性：

| 属性 | 含义 | 后续部署中如何变化 |
| --- | --- | --- |
| `input` | 程序本次传给 Stash 的当前值 | 每次部署都会反映最新输入 |
| `output` | Stash 保存在 state 中的值 | 默认保持第一次创建时的值 |

第一次部署时，input 和 output 通常相同。第二次部署如果程序传入了不同 input，Pulumi 会把新的 input 记录到资源输入里，但 output 仍然返回最初保存的值。

这不是异常，而是 Stash 的设计目标：**它把“当前程序想提交什么值”和“state 已经归档了什么值”分成两个通道。**

还有一个细节：Stash 和其他资源一样，资源名在同一个程序里必须唯一。上面的 `firstDeployer` 是 Pulumi 的逻辑名，后续如果要定向替换这个 Stash，URN 中也会包含这个名字。

## 保存复杂值

Stash 的 input 可以是字符串、数字、布尔值，也可以是对象、数组和嵌套结构。Pulumi 会把它序列化为 Pulumi property value 后保存进 state。

```ts
const deploymentProfile = new pulumi.Stash("deploymentProfile", {
    input: {
        stack: pulumi.getStack(),
        region: "us-west-2",
        services: ["api", "worker"],
        tags: {
            Environment: "production",
            Team: "platform",
        },
    },
});

export const initialProfile = deploymentProfile.output;
export const currentProfile = deploymentProfile.input;
```

保存复杂值时，建议保持结构小而清晰。它应该是“为了部署决策需要长期记住的摘要”，而不是一份不断增长的业务数据。

## 保存 secret

Stash 尊重 Pulumi 的 secret 标记。如果 input 是 secret，output 也会是 secret，并以加密形式写入 state。

```ts
const apiKeyStash = new pulumi.Stash("apiKeyStash", {
    input: pulumi.secret("my-secret-api-key"),
});

export const apiKey = apiKeyStash.output;
```

运行 `pulumi stack output` 时，secret 会显示为 `[secret]`。只有显式传入 `--show-secrets`，CLI 才会显示明文。

这也意味着：如果你把某个首次生成的密码用 Stash 保存起来，请先把它标记为 secret。否则 Stash 只会按普通值保存，state 中就可能出现明文。

## 更新保存值：必须替换 Stash

Stash 最容易被误解的地方在于更新行为。修改 input 后，output 不会自动变化。要更新 state 中保存的 output，必须让这个 Stash 资源发生替换。

官方列出三类做法：

| 方式 | 适合场景 | 示例 |
| --- | --- | --- |
| `--target-replace` | 偶尔手动刷新某个 Stash | `pulumi up --target-replace <urn>` |
| `pulumi state taint` | 先标记资源，下一次部署再替换 | `pulumi state taint <urn>` |
| `replacementTrigger` | 让任意触发值变化时自动替换 | 版本号、月份、外部配置修订号 |

这些命令都以资源 URN 定位具体资源。可以用 `pulumi stack --show-urns` 列出当前 Stack 中的 URN；`pulumi state taint` 可以一次接收一个或多个完整 URN，并让这些资源在下一次 `pulumi up` 时被销毁后重建。

例如，用 CLI 定向替换某个 Stash：

```bash
pulumi up --target-replace urn:pulumi:dev::my-project::pulumi:index:Stash::firstDeployer
```

定向更新是官方文档中明确标注的“应急通道”。它只调和被选中的资源，其他资源会继续使用 state 中记录的旧值，可能带来漂移或过期输入。因此，生产环境中建议先用同样参数执行 preview，完成一次性修复后尽快回到完整 Stack 更新。

如果希望代码里自动控制替换节奏，可以使用资源选项。在 Node.js SDK 中，该选项名是 `replacementTrigger`：

```ts
const remoteRevision = "2026-06";

const rememberedValue = new pulumi.Stash("rememberedValue", {
    input: fetchCurrentValue(),
}, {
    replacementTrigger: remoteRevision,
});
```

当同一个资源在连续两次部署中都有 replacementTrigger，且触发值发生变化时，Pulumi 会把资源标记为需要替换。需要注意：仅仅新增或移除这个选项不会触发替换，只有已经存在的触发值发生变化才会触发。

生产环境里建议把替换动作当成一次明确的状态变更来评审。因为替换 Stash 会改变以后所有读取 output 的逻辑，它的影响通常不在云资源本身，而在你的程序如何解释“首次值”。

## 删除 Stash

删除 Stash 很简单：从程序中移除对应资源声明，然后运行 `pulumi up`。Pulumi 会在这次更新中把该 Stash 从 Stack state 删除。

删除后，原先保存的 output 不再存在。若之后用同名 Stash 重新创建，它会作为一个新资源重新保存当时的 input。

## 使用检查清单

引入 Stash 前，可以用下面这张清单判断是否合适：

- 这个值是否由程序在部署时计算出来，而不是由环境配置决定？
- 这个值是否需要跨多次部署保持第一次的结果？
- 如果未来要刷新它，团队是否知道应该替换 Stash？
- 这个值如果是敏感数据，是否已经被标记为 secret？
- 这个值是否足够小，适合作为 state 的一部分保存？
- 删除或替换 Stash 后，读取它的代码是否有清晰预期？

一句话总结：**Config 管“当前环境要求什么”，Stash 管“第一次部署时已经记住什么”。** 两者都进入 Stack 的状态管理范围，但语义完全不同。

## 动手实验

本章实验使用本地后端和 TypeScript，只依赖 Pulumi 内置的 Stash 资源，不连接任何云 provider。你会依次观察 Stash 的创建、input 更新、定向替换、复杂值、secret 与删除行为。

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-stash" title="实验：Stash 状态暂存（纯本地）" desc="使用 @pulumi/pulumi 的内置 Stash 资源，在本地后端中观察 input 与 output 的差异、用 --target-replace 刷新保存值、保存复杂对象和 secret，并删除 Stash 资源。" />