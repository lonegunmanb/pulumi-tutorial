---
order: 30
title: 资源与精细控制
group: 第 2 篇：Concepts 深度剖析
---

# 资源与精细控制

## 本章定位

前几章我们建立了 Project、Stack、State 的心智模型。本章进入 Pulumi 的核心抽象——**Resource（资源）**：它是组成云基础设施的基本单元，一个 S3 Bucket、一个 Resource Group、一个 Virtual Machine 都是一个 Resource。

本章回答四个问题：

- 一个 Resource 在代码里、在 Pulumi 内部、在云上分别叫什么名字？（命名与身份）
- Pulumi 怎么知道哪些资源要先建、哪些要后建？（依赖）
- 怎么在不重建资源的前提下安全地重命名、重构、改属性？（Resource Options）
- 哪些操作会悄悄触发 `replace`（先建后删甚至先删后建），从而带来停机风险？

## 官方映射

- [Resources](https://www.pulumi.com/docs/iac/concepts/resources/)：`Resource` 基类、`CustomResource` 与 `ComponentResource`。
- [Resource names and identity](https://www.pulumi.com/docs/iac/concepts/resources/names/)：logical name、physical name、physical ID、URN 与 auto-naming。
- [Resource options](https://www.pulumi.com/docs/iac/concepts/resources/options/)：`protect`、`dependsOn`、`aliases`、`deleteBeforeReplace` 等全部选项。

## 3.1 一个 Resource 是怎么声明出来的

所有基础设施资源都继承自 `Resource` 基类，并分成两个子类：

- **`CustomResource`**：由某个 resource provider（AWS、Azure、GCP、Kubernetes……）管理的真实云资源。
- **`ComponentResource`**：把若干资源打包成一个更高层抽象的逻辑分组，本身不对应任何云资源（下一章详解）。

声明一个资源，就是用它的「期望状态」构造一个实例：

```ts
let res = new Resource(name, args, options);
```

这三个参数贯穿全章：

| 参数 | 含义 | 例子 |
|------|------|------|
| `name` | **logical name**（逻辑名），同类资源在一个 Stack 内必须唯一 | `"media-bucket"` |
| `args` | 输入属性对象，可以是原始值，也可以是其他资源的 `Output<T>` | `{ tags: { team: "platform" } }` |
| `options` | 可选的 Resource Options，控制依赖、保护、provider、导入等 | `{ protect: true }` |

要查某个资源支持哪些 `args`，去 [Pulumi Registry](https://www.pulumi.com/registry/) 看对应 provider 的 API 文档。

## 3.2 一个资源的四种身份

初学者最容易混淆的，就是一个资源「到底叫什么名字」。Pulumi 里一个资源同时有**四种身份**，各管各的用途：

| 身份 | 谁决定 | 例子 | 用途 |
|------|--------|------|------|
| **Logical name** | 你的代码（构造函数第一个参数） | `"my-bucket"` | 驱动 URN，通常也是物理名的前缀 |
| **Physical name** | provider，受 logical name + auto-naming 影响 | `"my-bucket-d7c3a1f"` | 真正调云 API 用的名字，从 provider 输出属性读回 |
| **Physical ID** | provider 创建后返回 | `"vpc-0abc1234"`、Azure ARM ID | `import`、`get` 与按 ID 引用资源时用，`resource.id` |
| **URN** | Pulumi 从 project/stack/type/logical name 推导 | `urn:pulumi:dev::app::aws:s3/bucket:Bucket::my-bucket` | Pulumi 内部全局唯一标识，CLI/state 用 |

![资源的四种身份：ID 卡、门牌、登记号与户籍档案](./images/resources-four-identities.png)

> 绘图提示词：light watercolor shaded comic illustration，cyan 主色调，拟物风格。画面把一个 cloud resource 拟人成一个住户，旁边并排展示四张卡片：一张写着 "logical name" 的 ID card（你给他起的名字）、一张写着 "physical name" 的 door plate 门牌（provider 挂上去的、带随机后缀）、一张写着 "physical ID" 的 registration number 登记号（provider 发的编号）、一张写着 "URN" 的户籍档案编号（Pulumi 内部档案）。四张卡片用细线连到同一个住户，强调"同一个资源、四种身份、各有用途"。technical terms 用英语，其余说明文字用中文。

最常见的错误，是把 **physical ID（`resource.id`）** 和 **URN（`resource.urn`）** 搞混：

- 云 provider 的 API、`pulumi import` 想要的是 **physical ID**。
- URN 几乎只在 Pulumi 内部使用，应用代码里很少直接碰。
- `dependsOn` 要的是**资源引用本身**（那个变量），既不是 URN 也不是 ID。Python 里写 `depends_on=[bucket]`，不要写 `depends_on=[bucket.urn]`。

### Logical name 与变量名无关

```ts
var foo = new aws.Thing("my-thing");
```

这里 `"my-thing"` 是 logical name，参与 URN；而变量 `foo` 只是代码里的引用，把它改成 `bar` 再 `pulumi up`，基础设施不会有任何变化（除非你 `export` 了它）。

## 3.3 Physical name 与 Auto-Naming

logical name 和 physical name 经常**不一样**。默认情况下，Pulumi 对大多数资源做 **auto-naming**：用 logical name 加一个随机后缀拼出物理名。所以 logical name 是 `my-role`，物理名往往是 `my-role-d7c2fa0`。

这个随机后缀有两个作用：

- **避免命名冲突**：同一个 project 的多个 stack（dev/staging/prod）可以同时部署而互不撞名。
- **支持零停机替换**：某些更新必须替换资源，Pulumi 默认**先创建新的、再把引用切过去、最后删旧的**，随机后缀让新旧资源能在替换期间共存。

### 覆盖 auto-naming：自己指定物理名

大多数资源有一个属性（常是 `name`，但因资源而异）可以直接指定物理名：

```ts
let role = new aws.iam.Role("my-role", { name: "my-role-001" });
```

> 注意：`aws.s3.Bucket` 用的属性是 `bucket` 而不是 `name`；`aws.kms.Key` 干脆没有物理名。具体看 Registry。

**一旦你显式指定物理名，就放弃了随机后缀带来的防撞名保护。** 对可能被替换的资源，要配合 `deleteBeforeReplace: true`，让 Pulumi 先删旧再建新，避免新旧同名冲突：

```ts
let role = new aws.iam.Role("my-role", {
  name: `my-role-${pulumi.getProject()}-${pulumi.getStack()}`,
}, { deleteBeforeReplace: true });
```

### 全局配置 auto-naming

除了逐个资源指定，还能用 `pulumi:autonaming` 配置统一控制命名策略。在 `Pulumi.<stack>.yaml` 里可以直接写：

```yaml
config:
  pulumi:autonaming:
    mode: default      # 默认：logical name + 随机后缀
```

常见模式：

| 配置 | 效果 | 风险 |
|------|------|------|
| `mode: default` | logical name + 随机后缀（等价于不配置） | 无 |
| `mode: verbatim` | 物理名 = logical name，无随机后缀 | 替换时会**先删后建**，可能停机 |
| `mode: disabled` | 强制所有资源显式指定物理名 | 漏写即报错 |
| `pattern: ${name}-${hex(8)}` | 自定义命名模板 | 模板无随机部分时同样先删后建 |

> 在 `Pulumi.yaml`（项目级）里配置时要多包一层 `value:` 键；在 `Pulumi.<stack>.yaml`（stack 级）里则可直接写。还能按 provider 或按资源类型分别配置，例如让 `azure-native` 用 `verbatim`、`storage:Account` 用 `${name}${string(6)}`。

一个关键提醒：**改动 autonaming 配置不会立刻重命名已有资源**，只影响此后新建或因其他原因被替换的资源。想让现有 dev stack 全部换名，得 destroy 再重建。

## 3.4 URN、资源类型与「改名即重建」

### Resource type token

每个资源都属于某个资源类型，格式是 `<package>:<module>:<typename>`：

- `aws:s3/bucket:Bucket`
- `azure-native:compute:VirtualMachine`
- `random:index:RandomPassword`

`<package>` 决定用哪个 Pulumi Package 和底层 provider，`<module>` 是包内模块路径，`<typename>` 是类型名。

### URN 怎么来的

URN 由 project 名、stack 名、资源类型、logical name，以及（对 component 子资源而言）所有父资源的类型链共同推导：

```text
urn:pulumi:production::acmecorp-website::custom:resources:Resource$aws:s3/bucket:Bucket::my-bucket
            ^stack       ^project          ^parent-type            ^resource-type        ^logical-name
```

URN 必须全局唯一。如果两个资源的 type + name + parent 都一样，会报 `Duplicate resource URN`。

### 这是本章最关键的一条规则

> **任何改变 URN 的操作，都会让 Pulumi 把它当成「旧资源删除 + 新资源创建」两个不相关的资源处理。**

会改变 URN 的操作主要有两类：

- 改了构造函数里的 **logical name**。
- 改了资源的**父子结构**（`parent`）。

这两种都会得到不同的 URN，于是触发 `create` + `delete`，而不是温和的 `update`/`replace`。**想改名又不想重建，必须用 `aliases` 选项**（见 3.7）。

## 3.5 Physical ID：认领既有资源的钥匙

资源创建完成后，provider 会分配一个 **physical ID**，通过 `resource.id` 输出属性暴露：

- AWS：`vpc-0abc1234`、bucket 名等（ARN 通常在单独的 `arn` 属性）。
- Azure：长长的 ARM ID `/subscriptions/<sub>/resourceGroups/...`。
- GCP：self-link URL。

因为 `id` 是 `Output<T>`，创建前不可知，用法和其他 output 一样——直接传给下一个资源的输入，或用 `.apply()` 变换：

```ts
const bucket = new aws.s3.Bucket("my-bucket");
const obj = new aws.s3.BucketObject("hello.txt", {
  bucket: bucket.id,        // 直接传 Output<string>，无需 .apply()
  content: "Hello, Pulumi!",
});
```

physical ID 在**认领既有云资源**时尤其重要：`import` 资源选项和 `get` 静态方法都接受 physical ID。

> 安全提示：physical ID 始终以明文存进 state，**无法加密**，即使用 `additionalSecretOutputs` 也不行。不要让敏感值出现在资源 ID 里。

## 3.6 依赖建模：Pulumi 怎么排执行顺序

### 隐式依赖（首选）

当一个资源的输入引用了另一个资源的 output，Pulumi 自动建立依赖，并据此排序：

```ts
const rg = new azure.core.ResourceGroup("app-rg", { location: "eastus" });
const account = new azure.storage.Account("data", {
  resourceGroupName: rg.name,   // 隐式依赖：account 一定在 rg 之后创建
  location: rg.location,
  accountTier: "Standard",
  accountReplicationType: "LRS",
});
```

### 显式依赖 `dependsOn`

当两个资源没有数据上的引用关系，但你确实需要保证顺序（例如某个 IAM 策略必须先生效），用 `dependsOn`：

```ts
const obj = new aws.s3.BucketObject("config", { /* ... */ }, {
  dependsOn: [bucket],          // 传资源引用，不是 .urn / .id
});
```

### `parent`、`provider` 与 `providers`

- `parent`：建立父子关系，影响 URN 和某些选项的继承（component 常用）。
- `provider`：给这个资源指定一个显式配置的 provider，而不是默认 provider（本章实验正是用它把资源指向本地模拟器）。
- `providers`：给一个 component 的所有子资源批量指定 provider。

## 3.7 Resource Options 全表

所有资源都支持一组通用选项。下表按官方分类列出，重点选项在 3.8 详解：

| 选项 | 作用 | 适用 |
|------|------|------|
| `additionalSecretOutputs` | 指定额外要加密的 output | custom |
| `aliases` | 重命名/重构时不触发替换 | custom + component |
| `customTimeouts` | 覆盖默认的创建/更新/删除超时 | custom |
| `deleteBeforeReplace` | 替换时先删旧再建新 | custom |
| `deletedWith` | 父资源被删时跳过本资源的 delete | custom |
| `dependsOn` | 在依赖图之外补充显式依赖 | custom + component |
| `hooks` | 在生命周期特定阶段运行自定义逻辑 | custom + component |
| `ignoreChanges` | diff 时忽略指定属性的变化 | custom |
| `import` | 把既有云资源纳入 Pulumi 管理 | custom |
| `parent` | 建立父子关系 | custom + component |
| `protect` | 标记保护，防止误删 | custom + component |
| `provider` | 使用显式配置的 provider | custom + component |
| `providers` | 给 component 的子资源指定 providers | component |
| `replaceOnChanges` | 把指定属性的变化当作强制替换 | custom |
| `retainOnDelete` | Pulumi 删除时把资源留在云上 | custom |
| `transforms` | 注册时动态改写资源属性 | custom + component |
| `version` | 锁定 provider 插件版本 | custom |

### Component 选项继承

当某些选项设在 component 上，会自动**沿父子链下传**给子资源，子资源无需重复设置。会继承的有：`aliases`、`deletedWith`、`protect`、`provider`、`providers`、`retainOnDelete`、`transforms`、`transformations`。

不会继承的（如 `dependsOn`、`ignoreChanges`、`customTimeouts`、`replaceOnChanges`）需要在每个子资源单独设置，或用 component 的 `transforms` 在子资源注册时注入。

> `additionalSecretOutputs`、`deleteBeforeReplace`、`import` 只能用于 custom resource，设在 component 上会报错。

## 3.8 关键选项详解

### `protect`：防止误删

把资源标记为受保护后，`pulumi destroy` 或任何会删除它的操作都会被拦截：

```ts
const db = new aws.rds.Instance("prod-db", { /* ... */ }, { protect: true });
```

想删除时，要先去掉 `protect`（或用 `pulumi state unprotect`）。生产数据库、State 存储桶等都建议加上。

### `aliases`：零重建的重命名/重构

3.4 说过，改 logical name 会触发 create+delete。如果你只是想**重命名代码里的资源、保留云上实体**，用 `aliases` 告诉 Pulumi「这个新名字其实就是以前那个资源」：

```ts
// 原来叫 "web"，现在想叫 "frontend"
const frontend = new aws.s3.Bucket("frontend", { /* ... */ }, {
  aliases: [{ name: "web" }],
});
```

这样 `pulumi preview` 就不再是「删 web、建 frontend」，而是「把 web 这条 state 记录改名为 frontend」，云上资源原地保留。重构父子结构时同理。

### `deleteBeforeReplace` 与 `replaceOnChanges`

- `replaceOnChanges`：把某些属性的变化**强制**当作替换，即使 provider 本来认为可以原地更新。
- `deleteBeforeReplace`：当替换发生时，**先删旧再建新**（默认相反）。指定了固定物理名、不能新旧共存时必须用它。

```ts
const role = new aws.iam.Role("app-role", {
  name: "app-role-fixed",
}, { deleteBeforeReplace: true });
```

> 代价：先删后建意味着存在一段「资源不存在」的窗口，可能停机。只在确有命名冲突时使用。

### `ignoreChanges`：与外部漂移和平共处

有些属性会被云平台、自动伸缩或其他工具在带外修改。如果你不想每次 `pulumi up` 都把它们改回来，用 `ignoreChanges` 忽略这些属性的 diff：

```ts
const svc = new aws.ecs.Service("svc", {
  desiredCount: 2,              // 初始值
}, { ignoreChanges: ["desiredCount"] });   // 之后由 autoscaler 接管，Pulumi 不再纠正
```

### `retainOnDelete`、`deletedWith` 与 `import`

- `retainOnDelete`：`pulumi destroy` 时把资源**留在云上**，只从 state 移除。适合迁移、交接或保护有状态资源。
- `deletedWith`：当指定的「伞资源」（如 Resource Group）也在被删时，跳过本资源自己的 delete API（反正会随父一起没）。
- `import`：用 physical ID 把一个**既有**云资源纳入管理，详见 [Stack 章的 state import](stacks.md) 与官方 Importing resources 指南。

## 3.9 生产检查清单

- [ ] 给生产数据库、状态存储、密钥等关键资源加 `protect: true`。
- [ ] 重命名或移动资源前，先 `pulumi preview` 看是不是 create+delete；如果是，改用 `aliases`。
- [ ] 显式指定物理名的资源，评估是否需要 `deleteBeforeReplace`。
- [ ] 会被外部系统改动的属性，用 `ignoreChanges` 列出来，避免无谓 diff。
- [ ] 谨慎使用 `verbatim`/无随机后缀的 autonaming，理解它在替换时会先删后建。
- [ ] 不要把敏感值放进资源的 physical ID（无法加密）。

## 动手实验

本章提供 **AWS** 与 **Azure** 两版实验，分别使用真实的云 provider SDK 对接本地模拟器，因此无需任何云账号或凭据：

- AWS 版用 `pulumi/pulumi-aws`（`@pulumi/aws`）对接 **MiniStack**，以 S3 Bucket 演示命名、依赖、`aliases`、`deleteBeforeReplace`、`protect` 与 `ignoreChanges`。
- Azure 版用 `pulumi/pulumi-azure`（`@pulumi/azure`）对接 **miniblue**，以 Resource Group 和 Storage Account 演示同一组概念，并额外展示 provider 如何改写物理名以满足命名约束。

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-resources-options" title="实验：资源与精细控制（AWS / MiniStack）" desc="用 @pulumi/aws 对接 MiniStack，观察 URN 与四种身份，并演示 deleteBeforeReplace、dependsOn、aliases 零重建迁移、protect 与 ignoreChanges。" />

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-resources-options-azure" title="实验：资源与精细控制（Azure / miniblue）" desc="用 @pulumi/azure 对接 miniblue，以 Resource Group 演示四种身份、auto-naming、deleteBeforeReplace、隐式/显式依赖、aliases、protect 与 ignoreChanges。" />

## 本章交付物

- 资源四种身份（logical name / physical name / physical ID / URN）的对照理解。
- 一份 Resource Options 速查表与「会触发替换」的操作清单。
- 一次用 `aliases` 完成的零重建重命名演示。
- 一次 `deleteBeforeReplace` 解决固定物理名替换冲突的演示。
- `protect` 拦截删除、`ignoreChanges` 忽略漂移的实践经验。