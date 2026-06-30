---
order: 75
title: Policy as Code
group: 第 3 篇：Pulumi OSS 工程化扩展与交付实践
---

# Policy as Code

<TutorialAcknowledgement />

## 本章定位

Policy as Code 是把组织规则写成可执行程序的一种治理方式。与其把“所有存储桶必须有负责人标签”“生产资源不能使用临时命名”“Resource Group 必须位于批准区域”写在文档里等待人工检查，不如把这些规则写成 Policy Pack，让 Pulumi 在 `preview` 或 `up` 阶段自动检查。

本章有两个边界需要先说明：

- Pulumi OSS CLI 支持本地运行 Policy Pack：在命令中显式传入 `--policy-pack`，即可在本机、CI 或自管理 Backend 中执行策略检查。
- Pulumi Cloud 提供更完整的策略治理体验：Policy Groups、预置策略包、Policy Findings、审计模式和集中配置等能力需要 Pulumi Cloud。

本教程聚焦可以在 OSS 工具链中独立完成的部分。因此正文会解释官方 Pulumi Policies 的完整模型，但动手实验只使用本地 Policy Pack，不要求登录 Pulumi Cloud。

## 官方映射

- [Policies](https://www.pulumi.com/docs/insights/policy/)：Policy as Code 的整体概念、执行模式、本地执行与 Pulumi Cloud 能力边界。
- [Get Started with Pulumi Policies](https://www.pulumi.com/docs/insights/policy/get-started/)：Pulumi Cloud 中 Policy Packs、Policy Groups 与 Policy Findings 的入口。
- [Policy Packs](https://www.pulumi.com/docs/insights/policy/policy-packs/)：预置策略包与自定义策略包的分类。
- [Pre-Built Packs](https://www.pulumi.com/docs/insights/policy/policy-packs/pre-built-packs/)：Pulumi 提供的 CIS、PCI DSS、HITRUST、NIST 等预置包。
- [Write your own policy packs](https://www.pulumi.com/docs/insights/policy/policy-packs/authoring/)：TypeScript、Python、OPA/Rego 策略包的编写、本地运行、配置与发布。
- [Policy Pack Project File](https://www.pulumi.com/docs/insights/policy/policy-packs/project-file/)：`PulumiPolicy.yaml` 的字段与版本规则。
- [Policy Metadata](https://www.pulumi.com/docs/insights/policy/policy-packs/metadata/)：策略的名称、描述、强制级别、严重程度、修复建议和配置 schema。
- [Policy Groups](https://www.pulumi.com/docs/insights/policy/policy-groups/)：Preventative 与 Audit 两类策略组。
- [Policy Findings](https://www.pulumi.com/docs/insights/policy/policy-findings/)：策略发现项的集中查看、分派、优先级和状态管理。
- [Policy CLI Reference](https://www.pulumi.com/docs/insights/policy/cli/)：`pulumi policy` 命令组与本地 `--policy-pack` 执行方式。

## 9.1 从规则文档到可执行策略

传统治理常见做法是发布规范：命名规范、标签规范、区域规范、安全基线。问题在于，规范本身不会阻止一次错误部署。它需要评审者记得检查，也需要执行者理解每条规则。

Policy as Code 把这些规则变成程序。Pulumi 在执行基础设施程序时，会把即将创建或更新的资源交给策略包检查。策略包可以报告违规信息；如果规则是 mandatory，部署会被阻止；如果规则是 advisory，命令会继续执行，但用户会看到警告。

这带来三个直接收益：

| 收益 | 说明 | 例子 |
|------|------|------|
| 提前发现 | 在资源创建前检查问题 | `pulumi preview --policy-pack ./policy-pack` 发现缺少 owner 标签 |
| 规则可版本化 | 策略跟代码一样进入版本控制 | 从提示性命名规则逐步升级为强制规则 |
| 反馈更具体 | 策略可以直接说明哪一个资源违反哪一条规则 | `aws:s3/bucket:Bucket assets must include tags.managedBy` |

需要注意：Policy as Code 不是替代云平台原生治理工具。它更适合在 IaC 工作流中提前阻止明显不合规的资源。云平台的 IAM、组织策略、审计日志、配置扫描仍然应该存在。

## 9.2 Pulumi Policies 的组件

官方文档把 Pulumi Policies 组织成几个层次：

| 层次 | 含义 | 本地 OSS 能力 | Pulumi Cloud 能力 |
|------|------|---------------|-------------------|
| Policy | 一条具体规则 | 支持 | 支持 |
| Policy Pack | 多条规则的集合 | 支持本地运行 | 支持发布、版本管理、集中配置 |
| Policy Group | 把策略包应用到 Stack 或云账号 | 不支持 | 支持 |
| Policy Findings | 展示和管理违规发现项 | 不支持 | 支持 |

本地实验中，你会直接使用 Policy Pack。命令形式是：

```bash
pulumi preview --policy-pack ../policy-pack
```

也可以在更新时执行：

```bash
pulumi up --policy-pack ../policy-pack
```

Pulumi Cloud 用户可以把策略包发布到组织，再通过 Policy Group 自动应用到一批 Stack 或云账号。这样开发者不需要每次手动传 `--policy-pack`，策略结果也会进入 Cloud 控制台。

## 9.3 Policy Pack 的目录结构

一个 TypeScript Policy Pack 通常包含这些文件：

```text
policy-pack/
	PulumiPolicy.yaml
	package.json
	index.ts
	tsconfig.json
```

`PulumiPolicy.yaml` 是策略包项目文件，类似 Pulumi 程序里的 `Pulumi.yaml`。官方文档要求文件名固定为 `PulumiPolicy.yaml`，并放在策略包根目录。

最小示例：

```yaml
runtime: nodejs
```

更完整的示例：

```yaml
runtime: nodejs
version: 0.1.0
main: .
description: Platform security and tagging policies
author: Platform Team
license: Apache-2.0
```

TypeScript/JavaScript 策略包的版本默认从 `package.json` 读取；如果 `PulumiPolicy.yaml` 中也写了 `version`，则以项目文件为准。发布到 Pulumi Cloud 时，同一个版本只能发布一次。

## 9.4 策略的元数据

每条策略都需要清楚说明“它是谁、检查什么、违反后怎么处理”。常见字段如下：

| 字段 | 是否常用 | 说明 |
|------|----------|------|
| `name` | 必填 | 策略包内唯一名称，建议稳定、短小、可读 |
| `description` | 必填 | 说明策略检查什么以及为什么需要它 |
| `enforcementLevel` | 常用 | `advisory`、`mandatory`、`disabled`，官方元数据还包含 `remediate` |
| `severity` | 可选 | `low`、`medium`、`high`、`critical` |
| `remediationSteps` | 可选 | 告诉使用者如何修复 |
| `url` | 可选 | 指向内部规范、云厂商文档或修复说明 |
| `tags` | 可选 | 用于分类和过滤 |
| `framework` | 可选 | 关联 CIS、PCI DSS、NIST 等控制项 |
| `configSchema` | 可选 | 用 JSON Schema 定义可配置项 |

下面是一条最小的资源级策略。它检查所有 AWS S3 Bucket，要求资源声明中包含 owner 标签：

```ts
import { PolicyPack } from "@pulumi/policy";
import type { ResourceValidationPolicy } from "@pulumi/policy";

const requireOwnerTag: ResourceValidationPolicy = {
	name: "require-owner-tag",
	description: "S3 buckets must declare an owner tag.",
	enforcementLevel: "mandatory",
	validateResource: (args, reportViolation) => {
		if (args.type !== "aws:s3/bucket:Bucket") {
			return;
		}

		const tags = (args.props.tags || {}) as Record<string, string>;
		if (!tags.owner) {
			reportViolation("S3 bucket must include an owner tag.");
		}
	},
};

new PolicyPack("platform-baseline", {
	policies: [requireOwnerTag],
});
```

这段代码里，`name` 用来稳定标识策略，`description` 解释策略目的，`enforcementLevel` 决定违规时是否阻断部署，`validateResource` 则是真正执行检查的函数。本地实验会使用这些基础字段；在生产策略中，建议补充修复说明和链接，让违规信息不仅能阻止错误，也能指导修复。

## 9.5 资源级策略与 Stack 级策略

Pulumi 策略分两类：资源级策略和 Stack 级策略。

资源级策略会逐个检查资源，适合判断某个资源自己的属性是否合规。例如：

- S3 Bucket 必须包含 owner 标签。
- Resource Group 必须位于批准区域。
- 安全组不能开放 `0.0.0.0/0` 到管理端口。
- 存储资源必须启用加密。

Stack 级策略会在资源注册完成后检查整个资源图。它适合判断资源之间的关系或整体数量。例如：

- 一个 Stack 中 S3 Bucket 数量不能超过三个。
- 所有数据库必须位于私有子网。
- 必须同时存在日志存储和告警资源。

::: tip 执行时机
Stack 级策略只在 `pulumi up` 时运行，不在 `pulumi preview` 时运行。大多数常见规则应优先写成资源级策略，因为它们能在 preview 阶段提供更早反馈。
:::

## 9.6 强制级别：advisory、mandatory、disabled

策略的强制级别决定违规时的行为：

| 级别 | 行为 | 适合阶段 |
|------|------|----------|
| `advisory` | 输出警告，但不阻止部署 | 新规则试运行、信息提示 |
| `mandatory` | 阻止 preview 或 update | 安全、合规、成本底线 |
| `disabled` | 不执行该策略 | 临时关闭或灰度调整 |

官方元数据还列出 `remediate`。它与 Pulumi Cloud/Neo 的自动修复工作流相关，本教程的本地实验不使用它。

生产实践通常会经历三个阶段：

1. 先用 advisory 观察命中范围，避免突然阻断大量现有项目。
2. 修复高频违规，补齐例外说明和策略配置。
3. 对关键规则改为 mandatory，进入 CI 与发布流程。

## 9.7 策略包配置

策略包可以有配置。配置文件常用于调整允许值、强制级别或组织标准。例如：

```json
{
	"all": "mandatory",
	"require-owner-tag": {
		"allowedOwners": ["platform-team", "security-team"]
	}
}
```

本地运行时可以传入：

```bash
pulumi preview --policy-pack ../policy-pack --policy-pack-config policy-config.json
```

策略代码需要主动读取这份配置。例如下面这条规则允许平台团队在 JSON 中配置合法负责人列表：

```ts
import { PolicyPack } from "@pulumi/policy";
import type { ResourceValidationPolicy } from "@pulumi/policy";

type OwnerPolicyConfig = {
	allowedOwners?: string[];
};

const requireAllowedOwner: ResourceValidationPolicy = {
	name: "require-owner-tag",
	description: "Resources must declare an owner from the allowed owner list.",
	enforcementLevel: "mandatory",
	configSchema: {
		properties: {
			allowedOwners: {
				type: "array",
				items: { type: "string" },
			},
		},
	},
	validateResource: (args, reportViolation) => {
		const config = args.getConfig<OwnerPolicyConfig>();
		const allowedOwners = config.allowedOwners || ["platform-team"];
		const tags = (args.props.tags || {}) as Record<string, string>;
		const owner = tags.owner;

		if (!owner || !allowedOwners.includes(owner)) {
			reportViolation(`Resource owner must be one of: ${allowedOwners.join(", ")}.`);
		}
	},
};

new PolicyPack("platform-baseline", {
	policies: [requireAllowedOwner],
});
```

这样，策略逻辑保持不变，不同团队可以通过配置文件调整 allowedOwners。

在 Pulumi Cloud 中，策略包发布后可以在 Policy Group 中配置。官方还支持通过 ESC 环境向策略包传递 `policyConfig`，但这属于 Pulumi Cloud/ESC 工作流，本教程不安排实验。

## 9.8 Policy Groups 与 Policy Findings

Policy Group 是 Pulumi Cloud 的组织级能力，用来把策略包应用到一批 Stack 或云账号。官方文档把它分为两类：

| 类型 | 作用对象 | 运行时机 | 是否阻断部署 |
|------|----------|----------|--------------|
| Preventative | Pulumi Stack | `pulumi preview` / `pulumi up` | mandatory 会阻断 |
| Audit | Stack 最新状态与云账号资源 | Stack 更新后或定期扫描 | 不阻断，只报告 |

Policy Findings 是 Pulumi Cloud 中查看策略发现项的页面。它把发现项组织成 Overview、Compliance、Issues 三类视图，支持按策略、资源、严重程度、负责人和状态筛选。

本教程不依赖 Pulumi Cloud，但你需要理解这两个概念：本地 Policy Pack 是“单次命令的检查”；Policy Groups 和 Policy Findings 则是“组织范围的持续治理”。

## 9.9 CLI 常用命令

官方 CLI 文档中，`pulumi policy` 命令组用于创建、发布和管理策略包：

| 命令 | 用途 | 是否需要 Pulumi Cloud |
|------|------|-----------------------|
| `pulumi policy new` | 从模板创建策略包 | 否 |
| `pulumi policy publish` | 发布策略包到组织 | 是 |
| `pulumi policy enable` | 在组织或策略组中启用策略包 | 是 |
| `pulumi policy disable` | 禁用策略包 | 是 |
| `pulumi policy ls` | 列出组织策略包 | 是 |
| `pulumi policy validate-config` | 验证策略包配置 | 是 |

本地执行策略不需要 `pulumi policy` 子命令，而是使用 `preview` 或 `up` 的参数：

```bash
pulumi preview --policy-pack ../policy-pack
```

可以同时运行多个策略包：

```bash
pulumi up --policy-pack ../pack-a --policy-pack ../pack-b
```

## 9.10 本地策略实践清单

在团队中引入本地 Policy Pack 时，可以使用下面这份清单：

| 检查项 | 建议 |
|--------|------|
| 规则命名 | 名称稳定，避免频繁改名影响历史记录 |
| 违规信息 | 说明哪个资源、违反什么、如何修改 |
| 强制级别 | 新规则先 advisory，关键规则再 mandatory |
| 测试 | 给策略函数写单元测试，覆盖通过与违规情况 |
| CI | 在 Pull Request 中运行 `pulumi preview --policy-pack` |
| 例外管理 | 不要在代码里硬编码大量例外，优先使用配置文件 |
| 版本管理 | 策略包版本升级时写清行为变化 |

## 小结

- Policy as Code 把组织规则变成可执行检查。
- 本地 Policy Pack 是 Pulumi OSS 可独立使用的能力。
- Pulumi Cloud 提供 Policy Groups、Policy Findings、预置策略包和集中配置。
- 资源级策略适合大多数属性检查，Stack 级策略适合资源关系和全局约束。
- advisory 用于提示，mandatory 用于阻断，disabled 用于关闭。
- 好的策略不仅要阻止错误，还要给出清晰修复路径。

## 动手实验

下面两个实验都使用本地模拟器，不需要真实 AWS 或 Azure 账号。它们会创建一个本地 Policy Pack，并在 preview 阶段阻断不合规资源。

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-policy-as-code-aws" title="实验：Policy as Code（AWS / MiniStack）" desc="使用 MiniStack 模拟 AWS S3，编写本地 Policy Pack 检查 S3 Bucket 标签、命名和资源数量，观察 advisory 与 mandatory 策略在 preview/up 中的表现。" />

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-policy-as-code-azure" title="实验：Policy as Code（Azure / miniblue）" desc="使用 miniblue 模拟 Azure Resource Group，编写本地 Policy Pack 检查 location、tags 与 Stack 资源数量，练习 --policy-pack 本地执行策略。" />
