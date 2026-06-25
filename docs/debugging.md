---
order: 78
title: Pulumi 调试与故障排查
group: 第 3 篇：Pulumi OSS 工程化扩展与交付实践
---

# Pulumi 调试与故障排查

## 本章定位

Pulumi 把基础设施程序、资源 Provider、Stack State 和真实云资源连接在一起。一次失败的更新，可能来自 TypeScript 代码、Stack 配置、Provider 认证、云服务 API、State 记录，也可能来自 CI 运行环境本身。排障时如果只盯着最后一行错误，很容易漏掉真正的原因。

本章讲解如何在不依赖 Pulumi Cloud 的前提下排查 Pulumi 项目的常见问题。重点覆盖配置错误、部署失败、资源依赖、日志诊断、状态检查、漂移识别与 CI 日志定位。Pulumi Cloud 提供的控制台历史、云端策略、托管部署与集中审计不作为本章实验前提；读者只需要本地 Pulumi CLI、语言运行时、自管理或本地 Backend，以及云 Provider 凭据。

本章的核心方法是：先判断故障发生在哪一层，再选择最小的一组命令取证，最后用代码、配置或 State 的受控操作修复。

## 官方映射

- [Troubleshooting Guide](https://www.pulumi.com/docs/iac/operations/troubleshooting/)：Pulumi 排障入口，覆盖更新冲突、服务端错误、连接问题、DIY Backend 访问错误、更新中断等场景。
- [Logging](https://www.pulumi.com/docs/iac/operations/debugging/logging/)：CLI verbose logging、Provider 诊断日志、程序日志以及 CI 中的日志环境变量。
- [pulumi preview](https://www.pulumi.com/docs/iac/cli/commands/pulumi_preview/)：预览资源变更，不实际修改 Stack；支持 `--diff`、`--json`、`--refresh`、`--debug` 等排障参数。
- [pulumi up](https://www.pulumi.com/docs/iac/cli/commands/pulumi_up/)：创建或更新 Stack 资源；支持 `--diff`、`--json`、`--refresh`、`--target`、`--exclude`、`--debug` 等参数。
- [pulumi refresh](https://www.pulumi.com/docs/iac/cli/commands/pulumi_refresh/)：读取真实云资源并更新 State；可用 `--preview-only` 先查看 refresh 计划。
- [pulumi stack export](https://www.pulumi.com/docs/iac/cli/commands/pulumi_stack_export/) 与 [pulumi stack import](https://www.pulumi.com/docs/iac/cli/commands/pulumi_stack_import/)：导出、检查和重新导入 Stack State。
- [pulumi state](https://www.pulumi.com/docs/iac/cli/commands/pulumi_state/)：对 State 做受控修复，例如 repair、delete、move、taint、unprotect 等。
- [Targeted updates](https://www.pulumi.com/docs/iac/operations/stack-management/targeted-updates/)：`--target`、`--exclude`、`--replace` 等定向操作的适用范围与风险。
- [Editing state files](https://www.pulumi.com/docs/iac/operations/stack-management/editing-state-files/)：不得不修复 State 时的安全步骤与 State 文件结构。
- [Troubleshooting Pulumi in CI/CD](https://www.pulumi.com/docs/iac/operations/continuous-delivery/troubleshooting/)：流水线中 backend 认证、Stack 名称、CLI、语言工具、依赖、Provider 凭据等检查项。

## 10.1 Pulumi 故障排查地图

一次 Pulumi 操作可以拆成五层：程序运行、配置读取、Provider 调用、State 读写和真实资源状态。先分层，后处理。

| 层次 | 常见症状 | 先看什么 | 常用命令 |
|------|----------|----------|----------|
| 语言程序 | TypeScript 编译失败、变量不存在、`apply` 回调抛错 | 终端里的 stack trace、文件路径、行号 | `npm test`、`pulumi preview` |
| Stack 配置 | 缺少必填配置、类型不匹配、Secret 解密失败 | `Pulumi.<stack>.yaml` 与命名空间 | `pulumi config`、`pulumi config get` |
| Provider | 认证失败、权限不足、资源已存在、API 参数错误 | Provider 诊断、云 API 返回码 | `pulumi up --logtostderr --logflow -v=9` |
| State | 资源记录与代码不一致、更新中断、资源 ID 异常 | State 导出文件、pending operations | `pulumi stack export`、`pulumi refresh` |
| 真实资源 | 控制台外修改、手工删除、配额或策略限制 | 云 CLI、云控制台、模拟器查询 | `pulumi preview --refresh`、云 CLI |

排障时建议从最便宜的检查开始：先运行 `pulumi preview --diff`，再看 Stack 配置；如果错误来自 Provider，再打开 verbose logging；如果怀疑真实资源被改动，再执行 refresh；只有在这些方法都不足以解决时，才进入 State 修复流程。

## 10.2 配置错误：缺失、命名空间、类型与 Secrets

配置错误通常发生在程序真正调用云 API 之前。Pulumi 程序运行时会读取当前 Stack 的配置文件；TypeScript 中常见的读取方式如下：

```ts
import * as pulumi from "@pulumi/pulumi";

const config = new pulumi.Config();

const owner = config.require("owner");
const environment = config.require("environment");
const replicaCount = config.getNumber("replicaCount") ?? 1;
const token = config.requireSecret("token");
```

`require` 与 `requireSecret` 适合真正必填的值。配置缺失时，Pulumi 会在 preview 或 up 阶段直接失败，并在 Diagnostics 中指出缺少哪个 key。`get`、`getNumber` 和 `getBoolean` 更适合有默认值的参数。

配置排查可以按下面的顺序进行：

```bash
pulumi stack
pulumi config
pulumi config get owner
pulumi config set owner platform-team
pulumi preview --diff
```

命名空间是初学者常见的混淆点。`new pulumi.Config()` 默认使用当前项目名作为命名空间，所以配置文件中会出现类似 `my-project:owner` 的 key。Provider 配置通常有自己的命名空间，例如 AWS 的 region 配置常写成 `aws:region`。如果你在代码中写了 `new pulumi.Config("platform")`，则需要设置 `platform:owner`。

Secrets 相关错误要分两类看：

| 现象 | 常见原因 | 建议处理 |
|------|----------|----------|
| 提示缺少 Secret 配置 | 没有执行 `pulumi config set --secret` | 重新设置 Secret |
| 提示无法解密 | passphrase、KMS、Key Vault 等加密材料不一致 | 确认 `PULUMI_CONFIG_PASSPHRASE` 或密钥访问权限 |
| CLI 输出隐藏值 | Secret 正常加密 | 不要为了查看方便随意使用 `--show-secrets` |
| CI 中本地正常、流水线失败 | Secret 环境变量未进入当前 job | 检查 CI secret 范围和步骤边界 |

如果需要导出 State 做诊断，默认不要带 `--show-secrets`。只有在受控环境中确认需要明文 Secret 时，才使用这个参数，并把导出文件按高敏感材料处理。

## 10.3 部署失败：Provider 与云 API 返回错误

部署失败通常发生在 Pulumi 已经完成程序执行，开始通过 Provider 调用云 API 之后。此时错误信息里通常会包含资源 URN、资源类型、操作名称和云服务返回的信息。

| 错误类别 | 典型线索 | 排查方向 |
|----------|----------|----------|
| 认证失败 | InvalidClient、ExpiredToken、NoCredentialProviders | 凭据变量、登录会话、CI secret 范围 |
| 权限不足 | AccessDenied、AuthorizationFailed、Forbidden | IAM policy、Azure role、目标订阅或账号 |
| 资源已存在 | AlreadyExists、Conflict、duplicate name | 固定物理名、导入现有资源、别名或改名策略 |
| 参数错误 | InvalidParameter、BadRequest、unsupported | Provider 文档、资源属性类型、区域支持情况 |
| 配额限制 | QuotaExceeded、LimitExceeded | 区域配额、服务限制、清理旧资源 |
| Provider 连接失败 | connection refused、timeout、TLS 错误 | endpoint、代理、证书、模拟器健康状态 |

第一步通常是保留完整输出：

```bash
pulumi up --diff 2>&1 | tee pulumi-up.log
```

如果普通日志不足以判断，可以打开引擎和 Provider 的详细日志：

```bash
pulumi up --logtostderr --logflow -v=9 2> pulumi-debug.log
```

`-v` 的数值越大，日志越详细。官方 Logging 文档说明 Pulumi verbose log level 可到 11；10 及以下会避免有意暴露已知凭据，11 会为了调试而有意输出部分已知凭据，所以团队协作中应优先使用 9 或 10，并在共享前检查和遮盖敏感信息。

默认情况下，verbose 日志会写入系统临时目录，常见位置是 `/tmp` 或 `TMPDIR` 指向的位置。CI 中更常用 `--logtostderr` 把日志收进当前步骤输出或重定向到文件，但要同时控制日志大小和保留时间。

对于由 Terraform provider 桥接而来的 Pulumi Provider，还可以临时打开 `TF_LOG`：

```bash
TF_LOG=TRACE pulumi up --logtostderr --logflow -v=10 2> provider-trace.log
```

这类日志常用于确认实际调用了哪个 endpoint、传入了哪个资源 ID、云 API 返回了哪个状态码。排查结束后应关闭高详细度日志，避免 CI 日志过大或暴露敏感上下文。

## 10.4 依赖问题：Output、dependsOn 与定向操作

Pulumi 通过资源输入里的 `Output<T>` 自动推导大多数依赖。例如把 VPC 的 ID 传给子网，子网自然会等 VPC 创建完成。你不需要为每条普通引用都手写 `dependsOn`。

需要显式依赖的典型场景是：两个资源之间没有通过输入属性直接相连，但真实平台要求顺序。例如先创建日志桶，再创建一个依赖该日志桶存在的配置对象；或者某个动态操作必须等一个外部初始化资源完成。

```ts
const policy = new aws.s3.BucketPolicy("policy", {
	bucket: bucket.id,
	policy: bucket.arn.apply((arn) => JSON.stringify({
		Version: "2012-10-17",
		Statement: [{
			Effect: "Allow",
			Principal: "*",
			Action: "s3:GetObject",
			Resource: `${arn}/*`,
		}],
	})),
}, { dependsOn: [bucket] });
```

如果部署顺序与预期不一致，先看 preview 中的资源计划，再列出完整 URN：

```bash
pulumi preview --diff --show-replacement-steps
pulumi stack --show-urns
```

定向操作适合临时处理受影响范围很小的问题，但它不是常规发布方式。官方 Targeted updates 文档强调：`--target`、`--exclude`、`--replace` 会让 Pulumi 只处理部分资源，可能让未处理的资源暂时偏离程序描述。使用前先 preview，处理后尽快回到完整 Stack 操作。

常见判断如下：

| 操作 | 适合情况 | 主要风险 |
|------|----------|----------|
| `--target <URN>` | 只处理一个小资源 | 依赖资源可能保留旧输入 |
| `--target-dependents` | 目标资源的下游也要一起处理 | 影响范围扩大 |
| `--exclude <URN>` | 大范围更新中跳过一个资源 | 被跳过资源继续偏离代码 |
| `--replace <URN>` | 强制某资源重建，但仍处理全栈 | 可能引发停机或数据变化 |
| `--target-replace <URN>` | 只重建某资源 | 仍有定向操作的状态风险 |

如果你经常需要定向操作，通常说明 Stack 太大或资源边界不清晰，应考虑拆分项目或 Stack，而不是长期依赖定向参数。

## 10.5 日志与诊断：CLI、程序与 Provider

Pulumi 有三类常用日志。

| 日志类型 | 来源 | 打开方式 | 适合排查 |
|----------|------|----------|----------|
| CLI verbose logging | Pulumi 引擎与插件流程 | `--logtostderr --logflow -v=9` | Provider 调用、资源 diff、内部步骤 |
| Program logging | Pulumi 程序代码 | `pulumi.log.info` 等函数 | 分支判断、配置摘要、关键变量 |
| Provider diagnostic logging | 具体 Provider | `TF_LOG` 或 Provider 自身变量 | 云 API 细节、HTTP 请求响应 |

TypeScript 程序中优先使用 Pulumi SDK 的日志函数，而不是只用 `console.log`：

```ts
pulumi.log.info("Preparing workload resources");
pulumi.log.debug("Detailed branch information");
pulumi.log.warn("The selected size is larger than the tutorial default");
```

`pulumi.log.debug` 默认不显示。运行 `pulumi preview --debug` 或 `pulumi up --debug` 时，才会看到 debug 级别的程序日志。`--debug` 关注程序日志与资源操作细节；`-v` 关注 CLI 和 Provider 的内部日志；复杂问题可以组合使用：

```bash
pulumi up --debug --logtostderr --logflow -v=9 2> pulumi-debug.log
```

CI 中如果不方便改命令，也可以通过环境变量设置 CLI 参数：

```bash
export PULUMI_OPTION_LOGFLOW=true
export PULUMI_OPTION_LOGTOSTDERR=true
export PULUMI_OPTION_VERBOSE=9
```

`pulumi logs` 是另一个容易混淆的命令。它是 experimental，用于聚合 Stack 中资源对应的 Provider 日志，例如 AWS 资源的 CloudWatch Logs。它不是查看 Pulumi 引擎日志的通用入口，也不保证每类资源都有可聚合的日志。在 OSS 排障中，优先掌握 `--logtostderr`、`--logflow`、`-v` 和程序日志。

使用 `pulumi logs` 还需要运行环境具备读取目标日志服务的权限。例如读取 AWS CloudWatch Logs，需要当前凭据能访问相关日志组；如果资源类型或 Provider 没有可聚合日志，这个命令也可能没有结果。

如果需要在 IDE 中暂停 Pulumi 程序或插件，`preview` 和 `up` 还提供 `--attach-debugger`。它更适合排查语言程序本身或自定义 Provider，不适合作为普通 CI 排障默认参数。

## 10.6 状态排查：导出、检查、备份与恢复

State 是 Pulumi 判断“当前 Stack 已经管理什么”的依据。它通常包含资源 URN、Provider 返回的物理 ID、inputs、outputs、依赖、parent、provider 引用、Secret 密文和操作元数据。

导出 State 是排查复杂问题时最重要的只读动作之一：

```bash
pulumi stack export --file state.json
jq '.deployment.resources[] | {urn, type, id, dependencies}' state.json
```

导出文件可以帮助你回答这些问题：

| 问题 | 观察字段 |
|------|----------|
| Pulumi 是否还记录着这个资源 | `deployment.resources[].urn` |
| Provider 使用哪个物理 ID | `id` |
| 输入和输出是否与预期一致 | `inputs`、`outputs` |
| 是否存在中断残留 | `pending_operations` |
| 删除为什么被拒绝 | `protect`、依赖字段 |

官方 Editing state files 文档建议：手工编辑 State 是最后手段。进入这一步之前，先尝试 refresh、更新 CLI 和 SDK、检查 provider 版本，或使用 `pulumi import`、`pulumi state` 子命令做更小范围的修复。

常见的 State 子命令包括 `pulumi state repair`、`pulumi state delete`、`pulumi state move`、`pulumi state taint` 和 `pulumi state unprotect`。这些命令比打开整份 JSON 文件更可控，也更容易留下清晰的操作记录。

如果必须修复 State，至少遵守下面的顺序：

```bash
pulumi stack export --file state-backup.json
pulumi stack export --file state-edit.json
# 在受控环境中修改 state-edit.json
pulumi stack import --file state-edit.json
```

不要直接编辑对象存储 Backend 里的 JSON 文件。通过 CLI 导出和导入，Pulumi 才能执行必要校验。团队协作时，修复 State 前还应明确告知其他成员暂停同一 Stack 的更新，避免两个操作同时写入 State。

## 10.7 漂移与修复：refresh 的正确顺序

Pulumi 的 preview 和 up 默认比较程序目标状态与当前 State。它们不会每次都主动从云 provider 读取全部真实资源。因此，控制台外修改、手工删除、云平台自动补全字段等情况，可能不会被普通 preview 立刻发现。

怀疑漂移时，先做 refresh 预览：

```bash
pulumi refresh --preview-only --diff
```

确认后再真正更新 State：

```bash
pulumi refresh --yes
```

refresh 只把真实资源状态写回 State，不会修改你的 Pulumi 程序。完成 refresh 后，再运行 preview，查看“代码目标状态”和“刷新后的 State”之间是否仍有差异：

```bash
pulumi preview --diff
```

如果 preview 显示需要把某些标签、配置或属性改回代码声明，说明真实资源已经偏离程序。此时可以通过 `pulumi up` 恢复，也可以修改代码承认新的真实状态；选择哪条路，取决于这次控制台外改动是否经过审核。

也可以把 refresh 放进 preview 或 up：

```bash
pulumi preview --refresh --diff
pulumi up --refresh --diff
```

大型 Stack 中 refresh 会增加时间和云 API 调用量。团队通常会在变更前、事故后、定期巡检或怀疑有人手工改动时主动执行，而不是对每次小改动都强制 refresh。

## 10.8 CI 中定位失败

CI 中的 Pulumi 失败看起来复杂，但官方 CI/CD troubleshooting 文档把基础要求归纳得很清楚。流水线执行 preview 或 up 至少需要：Backend 认证、已存在的 Stack、Pulumi CLI、语言运行时和构建工具、程序依赖、Provider 插件以及云 Provider 凭据。

本教程聚焦 OSS 工具链，因此 Backend 可能是本地文件、S3、Azure Blob、GCS 或 PostgreSQL。只有使用 Pulumi Cloud Backend 时，才需要 `PULUMI_ACCESS_TOKEN`。

| CI 阶段 | 常见失败 | 检查项 |
|---------|----------|--------|
| 登录 Backend | 找不到 Stack、认证失败 | Backend URL、访问令牌、对象存储权限 |
| 安装 CLI | `pulumi: command not found` | PATH、安装步骤是否跨 job 生效 |
| 恢复依赖 | 找不到 SDK 或插件 | `pulumi install`、包管理器缓存、插件缓存 |
| 运行程序 | Node/Python/Go/.NET 报错 | 语言版本、锁文件、私有包访问 |
| 调用 Provider | 403、401、找不到订阅 | 云凭据、角色权限、区域和账号 |
| 保存 State | 锁冲突、写入失败 | Backend 锁、网络、对象存储策略 |

CI 中建议归档三类制品：Pulumi 命令输出、preview 或 up 的 JSON 输出，以及脱敏后的 State 导出。示例：

```bash
mkdir -p ci-artifacts
pulumi preview --diff --non-interactive 2>&1 | tee ci-artifacts/pulumi-preview.log
pulumi stack export --file ci-artifacts/stack-state.json
```

如果需要机器读取 preview，可以使用 `--json`。但 JSON 输出不适合人直接阅读，通常应同时保留普通日志。

需要事件流形式的 preview JSON 时，可以查看 preview 命令文档中的 `PULUMI_ENABLE_STREAMING_JSON_PREVIEW`。这更适合平台后端或自定义工具持续消费事件；普通 CI 只保存完整 JSON 文件通常已经足够。

CI 中还要特别关注 Secrets Provider。使用 passphrase 时，`PULUMI_CONFIG_PASSPHRASE` 必须进入运行 Pulumi 的同一个步骤；使用 KMS、Azure Key Vault 或其他密钥系统时，流水线身份也必须具备解密权限。无论哪种方式，都不应把明文 Secret 写入日志或构建制品。

## 10.9 故障处理清单

遇到失败时，可以按这份清单推进：

| 顺序 | 动作 | 目的 |
|------|------|------|
| 1 | 记录命令、Stack、commit 和完整错误 | 保留现场 |
| 2 | 运行 `pulumi preview --diff` | 判断是否能在预览阶段复现 |
| 3 | 查看 `pulumi config` | 排除缺失配置和命名空间问题 |
| 4 | 打开 `--debug` 或程序日志 | 看代码分支与自定义诊断 |
| 5 | 打开 `--logtostderr --logflow -v=9` | 看 Provider 与引擎细节 |
| 6 | 执行 `pulumi refresh --preview-only` | 判断真实资源是否漂移 |
| 7 | 导出 State | 检查 URN、ID、依赖和 pending operations |
| 8 | 用最小改动修复代码、配置或 State | 避免扩大影响面 |
| 9 | 在 CI 中固化复现命令 | 防止同类问题重复出现 |

真正成熟的 Pulumi 排障流程，不是靠记住所有错误字符串，而是靠稳定的证据链：配置来自哪里，程序声明了什么，Provider 调用了什么，State 记录了什么，真实资源现在是什么。

## 小结

- Pulumi 故障应先分层：程序、配置、Provider、State、真实资源。
- `preview --diff` 是最便宜的第一检查；`up --diff` 用于执行前确认具体变化。
- `--debug` 主要打开程序诊断，`-v` 与 `--logflow` 更适合看引擎和 Provider 细节。
- `refresh` 用来让 State 重新读取真实资源，但它不会修改 Pulumi 程序。
- State 修复要先导出备份，优先使用 CLI 子命令，手工编辑只作为最后手段。
- CI 排障要同时检查 Backend、Stack、CLI、语言工具、依赖、插件和云凭据。

## 动手实验

下面两个实验都使用本地模拟器，不需要真实 AWS 或 Azure 账号。它们会故意制造缺失配置、Provider endpoint 错误和控制台外标签改动，让你练习 preview、debug logging、refresh、stack export 与 CI 制品归档。

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-debugging-aws" title="实验：Pulumi 调试与故障排查（AWS / MiniStack）" desc="使用 MiniStack 模拟 AWS S3，从缺失 Stack 配置开始，逐步打开程序日志和 Provider verbose 日志，再通过 awslocal 制造标签漂移，用 refresh 与 state export 定位差异。" />

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-debugging-azure" title="实验：Pulumi 调试与故障排查（Azure / miniblue）" desc="使用 miniblue 模拟 Azure Resource Group，定位缺失配置、metadata endpoint 错误和控制台外标签漂移，练习 --debug、-v、refresh 与状态导出。" />