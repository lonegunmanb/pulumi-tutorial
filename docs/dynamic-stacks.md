---
order: 58
title: 多环境 Stack 配置与动态基础设施
group: 第 3 篇：Pulumi OSS 工程化扩展与交付实践
---

# 多环境 Stack 配置与动态基础设施

## 本章定位

::: tip 导言
前面的 [Stack 详解](stacks.md) 已经讲清楚 Stack 的生命周期：创建、选择、重命名、删除、状态导出，以及 active stack 对 CLI 命令的影响。[Configuration 配置](configs.md) 则讲清楚配置键、命名空间、结构化配置和机密配置。本章不重复这些基础操作，而是进入一个更贴近生产的问题：**同一套基础设施代码，怎样被 dev、staging、prod 等环境的配置矩阵驱动，形成不同但可审查的资源形态。**
:::

本章把 Stack、Configuration、Secrets、Outputs、资源依赖和自管理 Backend 串起来，回答以下问题：

- 如何把区域、标签、容量、网络 CIDR、功能开关等环境差异整理成配置矩阵？
- 什么时候使用 `pulumi.getStack()`，什么时候应当使用 Stack 配置？
- 如何用同一套程序按环境创建不同数量或不同类型的资源？
- 条件资源会带来哪些状态变化，为什么必须先看 `pulumi preview`？
- Secrets 配置怎样按环境隔离，并在输出和状态中保持机密性？
- 如何用 Outputs 连接跨资源数据流，让 Pulumi 自动建立依赖？
- 如何用 `pulumi refresh` 识别真实环境里被手工改动过的资源？
- 在不依赖托管控制台的前提下，怎样用 Git、状态备份和自管理 Backend 做变更管理与恢复？

## 与 Stack 章的分工

这章仍然会使用 dev 与 prod 两个 Stack，但它们只是环境实例，不是教学主角。两章的分工可以这样理解：

| 主题 | Stack 详解 | 本章 |
|---|---|---|
| 创建、选择、列出、删除 Stack | 重点 | 只作为前置条件 |
| Stack 配置文件的存在形式 | 重点 | 作为配置矩阵的载体 |
| `pulumi.getStack()` | 认识当前环境 | 只用于环境标签、命名后缀和少量分支 |
| 配置值如何读写 | 基础操作 | 组合成区域、容量、网络与功能开关 |
| State export | 理解状态结构 | 作为变更前备份手段 |
| `pulumi preview` / `pulumi refresh` | 基础命令 | 作为变更审查和漂移检测流程 |

如果说 Stack 章讲的是“每个环境有自己的边界”，本章讲的就是“这些边界里面到底有什么差异，以及这些差异如何被治理”。

## 官方映射

- [Stacks](https://www.pulumi.com/docs/iac/concepts/stacks/)：同一 Project 的多个隔离实例，每个 Stack 有自己的配置和状态。
- [Configuration](https://www.pulumi.com/docs/iac/concepts/config/)：Stack 配置、项目级配置、结构化配置、Provider 配置和配置命名空间。
- [Secrets](https://www.pulumi.com/docs/iac/concepts/secrets/)：用 `--secret`、`getSecret`、`requireSecret` 管理机密配置，并让机密性沿 Output 传播。
- [Inputs and Outputs](https://www.pulumi.com/docs/iac/concepts/inputs-outputs/)：用 Output 表达运行期值，并让资源之间的依赖自动形成。
- [State](https://www.pulumi.com/docs/iac/concepts/state/)：理解状态文件、状态备份和 Backend 的职责。
- [Refresh](https://www.pulumi.com/docs/iac/cli/commands/pulumi_refresh/)：从真实云环境读取当前状态，用于识别和处理漂移。

## 6.1 多环境的核心矛盾：同一套代码，不同运行边界

基础设施代码一旦进入团队协作，几乎不会只有一个环境。开发环境需要快速、廉价、容易销毁；预发环境需要尽量接近生产；生产环境则强调容量、隔离、审计和恢复能力。它们共享同一套架构意图，却不应该共享同一组参数。

把这些差异写进代码分支很诱人，例如在程序里判断当前环境是不是 prod，然后改变实例数量或网络范围。但这种做法会让代码变成环境规则的堆积处：程序越来越难读，变更也越来越难审查。更稳妥的方式是把环境差异显式整理到 Stack 配置里，让代码保持“结构模板”的角色。

一个常见配置矩阵如下：

| 配置项 | dev | staging | prod |
|---|---:|---:|---:|
| region | us-east-1 | us-east-1 | us-west-2 |
| capacity | 1 | 2 | 4 |
| cidrBlock | 10.10.0.0/16 | 10.20.0.0/16 | 10.30.0.0/16 |
| subnetCount | 1 | 2 | 3 |
| enableAccessLogs | false | true | true |
| enablePrivateSubnet | false | true | true |
| owner | platform-dev | platform | platform |
| dataClass | test | staging | restricted |

这张表不是文档装饰，它应该能一一落到 `Pulumi.dev.yaml`、`Pulumi.staging.yaml` 和 `Pulumi.prod.yaml` 里。配置文件提交到 Git 后，环境差异就变成了可以评审、可以回滚、可以追踪历史的工程资产。

## 6.2 Stack 配置模型：项目默认值与环境覆盖

Pulumi 配置有两个常用层次：

- Project 默认配置写在 `Pulumi.yaml`，适合所有环境共享的默认值。
- Stack 配置写在 `Pulumi.<stack>.yaml`，适合每个环境自己的覆盖值。

当两个层次设置了同一个键时，Stack 配置优先。也就是说，Project 级配置适合提供默认值，而环境级差异应当由 Stack 配置覆盖。

例如项目级默认值可以写团队标签和默认区域：

```yaml
# Pulumi.yaml
name: platform-app
runtime: nodejs
config:
  platform-app:owner: platform-team
  aws:region: us-east-1
```

::: warning Project 级结构化配置语法不同
上面的 Project 级示例只放了标量默认值。若要在 `Pulumi.yaml` 中写结构化配置，官方语法与 Stack 配置文件不同，需要使用 `value:` 包一层；而 `Pulumi.<stack>.yaml` 中的结构化配置可以直接嵌套在键名下。生产项目中建议把大段环境矩阵放在 Stack 配置文件里，Project 级只保留少量共享默认值。
:::

而生产环境覆盖容量、区域和网络：

```yaml
# Pulumi.prod.yaml
config:
  aws:region: us-west-2
  platform-app:owner: platform-prod
  platform-app:settings:
    namePrefix: platform-prod
    capacity: 4
    cidrBlock: 10.30.0.0/16
    subnetCount: 3
    enableAccessLogs: true
    tags:
      environment: prod
      owner: platform
      dataClass: restricted
```

读取时用结构化配置更清晰：

```ts
import * as pulumi from "@pulumi/pulumi";

interface EnvironmentSettings {
	namePrefix: string;
	capacity: number;
	cidrBlock: string;
	subnetCount: number;
	enableAccessLogs: boolean;
	tags: Record<string, string>;
}

const stack = pulumi.getStack();
const config = new pulumi.Config();
const settings = config.requireObject<EnvironmentSettings>("settings");

const commonTags = {
	...settings.tags,
	environment: stack,
	managedBy: "pulumi",
};
```

这里的 `pulumi.getStack()` 只负责告诉程序当前环境名。真正决定资源形态的是 `settings`。这是一条重要边界：**Stack 名适合做标签、命名后缀和少量环境识别；容量、区域、网络范围和功能开关应当放进配置。**

## 6.3 参数化与复用：区域、标签、容量、网络与功能开关

参数化不是把所有值都变成字符串，而是把环境差异整理成有类型、有含义的输入。以网络为例，代码不应该只读取一个松散的 `subnet1`、`subnet2`，更适合读取一个对象：

```yaml
config:
	platform-app:network:
		cidrBlock: 10.30.0.0/16
		subnets:
			- name: app
				cidrBlock: 10.30.1.0/24
				public: true
			- name: data
				cidrBlock: 10.30.2.0/24
				public: false
```

程序把这个对象映射成资源：

```ts
interface SubnetConfig {
	name: string;
	cidrBlock: string;
	public: boolean;
}

interface NetworkConfig {
	cidrBlock: string;
	subnets: SubnetConfig[];
}

const network = config.requireObject<NetworkConfig>("network");

for (const subnet of network.subnets) {
	// 这里创建云厂商的 subnet 资源。
	// 子网数量和地址段来自 Stack 配置，而不是硬编码。
}
```

参数化的目标不是“所有东西都可配置”，而是把稳定结构与环境变量分清楚。下面这些值通常适合配置化：

- 区域：如 AWS region 或 Azure location。
- 标签：如 owner、costCenter、environment、dataClass。
- 容量：如实例数、队列分片数、桶数量、子网数量。
- 网络：如 VPC/VNet CIDR、子网列表、私有网络开关。
- 功能开关：如是否开启访问日志、是否创建审计资源。
- 保留策略：如是否启用保护、是否保留备份。

不适合配置化的是资源之间的根本架构关系。例如“生产环境是否使用对象存储”如果经常在配置里开关，说明架构边界可能还没有稳定下来；如果只是“生产环境额外创建日志桶”，那就是合理的条件资源。

## 6.4 条件资源：按环境创建、跳过或扩展

Pulumi 程序是普通语言程序，因此可以使用条件语句创建资源：

```ts
let accessLogBucket: aws.s3.Bucket | undefined;

if (settings.enableAccessLogs) {
	accessLogBucket = new aws.s3.Bucket("access-logs", {
		tags: {
			...commonTags,
			purpose: "access-logs",
		},
	});
}
```

这种写法很强大，也需要谨慎。条件从 false 变成 true 时，Pulumi 会计划创建新资源；从 true 变成 false 时，Pulumi 会计划删除资源。如果这个资源保存了重要数据，配置变更就不只是“改一个布尔值”，而是一次可能删除资源的基础设施变更。

因此，条件资源必须遵守三条规则：

- 条件值必须来自 Stack 配置，并进入代码评审。
- 每次修改条件值后先运行 `pulumi preview`，确认新增或删除的资源符合预期。
- 对保存重要数据的条件资源，结合 `protect`、备份策略或明确的迁移步骤。

条件资源适合表达环境差异，不适合隐藏高风险操作。生产环境中，删除数据类资源通常应该拆成独立变更，而不是顺手跟随一个配置开关完成。

## 6.5 环境专属 Secrets：配置值可以相同，密文必须隔离

Secrets 是配置的一部分，但它的治理要求更高。dev、staging 和 prod 即使使用同一个键名，也应当拥有各自独立的值：

```bash
pulumi config set apiToken dev-token --secret --stack dev
pulumi config set apiToken prod-token --secret --stack prod
```

程序里用 `requireSecret` 读取：

```ts
const apiToken = config.requireSecret("apiToken");

export const tokenHint = apiToken.apply((value) => `token length: ${value.length}`);
```

派生自 secret 的 Output 会继续保持机密性。即使 `tokenHint` 只输出长度，它仍会在普通 `pulumi stack output` 中被遮蔽。这种“机密性传播”避免了开发者在组合字符串或 JSON 时意外泄漏敏感值。

在 OSS 教程范围内，可以使用本地 secrets provider 或自管理 Backend。关键原则是：

- 不把明文机密写进代码、README、普通环境变量示例或未加密配置。
- Stack 配置文件可以提交到 Git，但 secret 值必须是加密后的密文。
- 管理加密口令、KMS 权限或自管理 Backend 凭据时，要有团队级轮换与恢复流程。

## 6.6 Outputs 与资源依赖：让数据流带出执行顺序

多环境代码里常见的错误，是试图把资源输出当成普通字符串使用。Output 代表部署期间才知道的值，它既携带值，也携带依赖关系。正确做法是把 Output 直接传给下游资源输入，让 Pulumi 自动建立顺序。

例如对象存储桶创建后，再写入一份环境清单：

```ts
const bucket = new aws.s3.Bucket("app-data", {
	tags: commonTags,
});

const manifest = new aws.s3.BucketObject("environment-manifest", {
	bucket: bucket.bucket,
	key: "manifest.json",
	content: pulumi.jsonStringify({
		stack,
		bucket: bucket.bucket,
		tags: commonTags,
	}),
});
```

这里不需要手写 `dependsOn`。因为 `manifest.bucket` 引用了 `bucket.bucket`，Pulumi 能看出对象必须等桶创建完成。只有在没有数据引用但确实需要顺序约束时，才使用显式 `dependsOn`。

输出也承担跨团队交接的职责。一个环境部署完成后，可以导出最小必要信息：

```ts
export const environment = stack;
export const bucketName = bucket.bucket;
export const manifestKey = manifest.key;
```

输出不是日志。不要把所有内部细节都导出，只导出下游项目或运维流程真正需要的值。

## 6.7 变更审查：先 preview，再决定是否 up

配置矩阵让变更更清晰，但不会自动让变更更安全。安全来自流程：任何会影响资源形态的配置改动，都应当先经过 preview。

典型流程如下：

```bash
git diff -- Pulumi.prod.yaml
pulumi preview --stack prod
```

评审时重点看四类信息：

- 新建资源：是否只是预期的容量扩展或功能开关开启？
- 更新资源：是否为原地更新，是否会造成短暂不可用？
- 替换资源：是否涉及物理名、区域、地址段等 ForceNew 属性？
- 删除资源：是否包含数据类资源或生产流量路径？

对于生产环境，`pulumi up` 不应当只是一个人的本地动作。即使只使用 OSS 工具链，也可以用通用 CI 系统运行 preview，把输出作为代码评审的一部分。合并后再由受控环境执行 up，并把 Stack 配置、程序代码和状态备份一起纳入发布记录。

## 6.8 漂移检测：用 refresh 识别真实环境偏移

漂移指真实云资源与 Pulumi State 记录不一致。常见原因包括手工在控制台改标签、临时脚本改容量、云厂商默认值变化，或紧急修复后没有回写 IaC。

`pulumi refresh` 会向 provider 查询真实资源，把查询结果与当前 State 对比，并在确认后更新 State。随后再运行 preview，就能看到“为了回到代码声明的目标状态，还需要做什么”。

建议流程：

```bash
pulumi refresh --stack prod
pulumi preview --stack prod
```

如果希望在预览或更新前顺带刷新状态，也可以使用命令自带的 `--refresh` 选项：

```bash
pulumi preview --refresh --stack prod
pulumi up --refresh --stack prod
```

理解这两个命令的分工很重要：

- `refresh` 让 State 承认真实世界现在是什么样。
- `preview` 再根据代码与配置计算应该怎样回到目标状态。

发现漂移后不要急着一律覆盖。先判断漂移来源：如果是人为误改，通常应当用 up 恢复到代码声明；如果是一次合理的紧急变更，就应当把变更补回代码和配置，再用 preview 确认没有额外差异。

## 6.9 变更管理与恢复：Git、状态备份与自管理 Backend

本教程聚焦 Pulumi OSS，不依赖托管部署、审计或托管策略能力。即便如此，团队仍然可以建立可靠的变更管理流程。

第一层是 Git。基础设施程序、`Pulumi.yaml` 和所有非机密明文配置都应当进入版本控制。变更时先看 diff，再看 preview。配置文件里的 secret 密文也可以提交，但加密口令或 KMS 权限不能提交。

第二层是状态备份。重大变更前导出当前 Stack 状态：

```bash
mkdir -p backups
pulumi stack export --stack prod > backups/prod-before-change.json
```

这个文件可能包含敏感信息，应当按密件处理。它的价值在于：当自管理 Backend 出现误删、损坏或人为错误时，你至少保留了一份可供人工检查和必要恢复的状态快照。真正执行 state import 前必须先确认备份来源、Stack 名称、Backend 位置和当前云上资源情况，避免把旧状态强行覆盖到新现实上。

第三层是自管理 Backend。常见选择包括本地文件系统、对象存储或组织内部的状态存储服务。无论选哪一种，都要回答四个问题：

- 状态文件由谁有读写权限？
- 状态和 secret 加密材料如何备份？
- 并发更新如何避免互相覆盖？
- 误操作后如何恢复到某个已知快照？

这些问题不属于某个托管平台的专属能力。使用 OSS 工具链时，团队需要把它们纳入自己的平台工程规范。

## 6.10 生产检查清单

- [ ] dev、staging、prod 的差异已经整理成配置矩阵，而不是散落在代码分支里。
- [ ] Stack 配置文件已提交到 Git，并能通过代码评审看到环境差异。
- [ ] `pulumi.getStack()` 只用于环境识别、标签、命名后缀和少量必要分支。
- [ ] 区域、容量、标签、网络 CIDR、功能开关都来自有类型的配置对象。
- [ ] 条件资源的开启和关闭都会经过 `pulumi preview` 审查。
- [ ] 生产数据类资源启用了保护、备份或明确的迁移流程。
- [ ] 每个环境有独立 secret 值，程序使用 `requireSecret` 或 `getSecret` 读取。
- [ ] 资源之间优先通过 Output 输入建立依赖，只有无数据引用时才使用 `dependsOn`。
- [ ] 重大变更前导出状态备份，并按敏感文件管理。
- [ ] 定期运行 `pulumi refresh` 和 `pulumi preview` 检查漂移。
- [ ] 自管理 Backend 的访问控制、备份、并发控制和恢复流程已经文档化。

## 动手实验

本章实验分为 AWS 与 Azure 两个版本。两者都不需要真实云账号，重点也不是重复 Stack 创建流程，而是观察同一套代码如何被 dev/prod 配置矩阵驱动出不同资源形态，再用 preview、refresh 和备份流程治理变更。

AWS 版使用 `pulumi/pulumi-aws` 对接本地 MiniStack。你会用配置控制 S3 Bucket 数量、访问日志桶开关、环境标签和 secret 输出，再用 CLI 手工改动桶标签，观察 `pulumi refresh` 与 `pulumi preview` 如何识别并修复漂移。

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-dynamic-stacks-aws" title="实验：动态 Stack 配置（AWS / MiniStack）" desc="用 @pulumi/aws 对接 MiniStack，让 dev/prod 配置矩阵驱动 S3 Bucket 数量、访问日志开关、标签与 Secret 输出，并练习 preview、refresh、状态备份和配置恢复。" />

Azure 版使用 `pulumi/pulumi-azure` 对接本地 miniblue。你会用 Resource Group、Virtual Network 和 Subnet 表达环境级网络差异：dev 使用较小 CIDR 和单子网，prod 使用更大的地址空间、更多子网和条件创建的私有子网，再练习标签漂移检测与恢复。

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-dynamic-stacks-azure" title="实验：动态 Stack 配置（Azure / miniblue）" desc="用 @pulumi/azure 对接 miniblue，让 dev/prod 配置矩阵驱动 Resource Group、Virtual Network 与 Subnet 拓扑，并练习 preview、refresh、状态备份和配置恢复。" />

## 本章交付物

- 一份 dev/prod 环境配置矩阵，包含区域、标签、容量、网络和功能开关。
- 一套由配置驱动的 Pulumi 程序，避免为不同环境复制代码。
- 一个条件资源示例，理解配置开关如何改变资源集合。
- 一个 secret 配置示例，观察机密输出的遮蔽与传播。
- 一次 preview 审查，确认配置变更会造成哪些资源操作。
- 一次 refresh 漂移检测，理解 State、真实资源和代码目标状态之间的关系。
- 一份变更前状态备份与配置恢复演练流程。