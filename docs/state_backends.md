---
order: 26
title: State 与 Backend
group: 第 2 篇：Concepts 深度剖析
---

# State 与 Backend

## 本章定位

前两章已经说明：Stack 是一次独立部署，State 记录这次部署已经拥有哪些资源。本章继续回答一个更实际的问题：**这本 State 账本放在哪里，由谁负责保管、加锁、备份和授权？**

Pulumi 把保存 State 的位置称为 Backend。Backend 不是云资源 provider，也不是你要部署的基础设施本身；它是 Pulumi CLI 读写 Stack 状态、协调更新、保存历史记录的存储端点。

如果用资产登记簿作比喻：State 是登记簿内容，Backend 是放登记簿的柜子。柜子可以是 Pulumi Cloud，也可以是你自己管理的 S3、Azure Blob、GCS、PostgreSQL 或本地文件系统。选择哪一种柜子，会影响团队协作、访问控制、备份恢复、审计和故障处理方式。

![State backend 像把资产登记簿放进不同保险柜](./images/state-backends-ledger.png)

## 官方映射

- [Managing state & backend options](https://www.pulumi.com/docs/iac/concepts/state-and-backends/)：State 的作用、Backend 类型、登录/退出 Backend、刷新 State、导出导入 State。
- [Using a DIY Backend](https://www.pulumi.com/docs/iac/operations/stack-management/using-a-diy-backend/)：S3、Azure Blob、GCS、PostgreSQL、本地文件系统等自管理 Backend 的 URL 格式与配置方式。
- 相关页面：[Configuration and Secrets](https://www.pulumi.com/docs/iac/concepts/config/)、[pulumi login](https://www.pulumi.com/docs/iac/cli/commands/pulumi_login/)、[pulumi stack export](https://www.pulumi.com/docs/iac/cli/commands/pulumi_stack_export/)、[pulumi refresh](https://www.pulumi.com/docs/iac/cli/commands/pulumi_refresh/)。

## 2B.1 State 里到底保存什么

Pulumi State 保存的是某个 Stack 的最新快照，也就是 Pulumi 上次确认的基础设施记录。它通常包含：

| 内容 | 例子 | 为什么重要 |
|------|------|------------|
| 资源 URN | `urn:pulumi:dev::app::aws:s3/bucket:Bucket::assets` | Pulumi 识别每个资源的内部身份 |
| 资源 ID | S3 bucket 名、Azure ARM ID | provider 后续更新、读取和删除资源所需的真实标识 |
| 输入与输出 | tags、endpoint、resource group 名 | 用于 diff、输出查询与跨 Stack 读取 |
| 依赖关系 | A 资源依赖 B 资源 | 决定创建、更新和删除顺序 |
| Secret 标记与密文 | `secure:` 字段 | 让敏感值在 State 中保持加密 |
| 操作元数据 | manifest、版本信息 | 用于诊断和兼容性判断 |

State 不保存云账号凭据。AWS、Azure、GCP 等 provider 凭据仍留在运行 Pulumi CLI 的机器上。即使使用 Pulumi Cloud，Pulumi Cloud 也不需要你的云账号访问密钥来代表你执行部署；真正调用云 API 的仍是本地或 CI 中运行的 Pulumi 进程。

这个边界很关键：

- Backend 凭据决定 CLI 能不能读写 State。
- Provider 凭据决定程序能不能创建、读取、更新和删除云资源。
- Secret 加密方式决定敏感配置和敏感输出如何写入 State。

同一次 `pulumi up` 可能同时需要两套权限。例如使用 S3 作为 Backend、同时部署 Azure 资源时，CLI 需要能读写 S3 bucket，Azure provider 还需要能访问目标 Azure 订阅。这两套权限不能混为一谈。

## 2B.2 Backend 的两大类

Pulumi 支持两大类 Backend。

| 类型 | 存储位置 | 适合场景 | 你需要负责什么 |
|------|----------|----------|----------------|
| Pulumi Cloud | Pulumi 托管服务或自托管 Pulumi Cloud | 团队协作、审计、RBAC、历史记录、策略与控制台体验 | 配置组织、成员与访问令牌 |
| DIY Backend | 你管理的对象存储、数据库或本地目录 | 只使用 OSS 工具链、需要把 State 放在自有存储中 | 加密、备份、访问控制、审计、锁冲突处理 |

默认执行 `pulumi login` 时，CLI 会连接 Pulumi Cloud。这个体验最完整，因为 Pulumi Cloud 提供了事务化 API、更新历史、组织权限、审计能力以及漂移检测等功能。

本教程聚焦 Pulumi OSS，所以动手实验使用 DIY Backend。DIY Backend 同样能可靠保存 State，并且默认启用文件形式的锁与历史记录；但它把更多运维职责交给你所在的团队。例如对象存储的备份策略、桶策略、容器权限、密钥轮换、异常更新后的处理流程，都需要你自己制定。

## 2B.3 登录、退出与查看当前 Backend

选择 Backend 的入口是 `pulumi login`。

```bash
pulumi login
```

不带参数时，CLI 使用默认 Pulumi Cloud Backend。要连接指定 Backend，把 URL 作为参数传入：

```bash
pulumi login <backend-url>
```

查看当前 Backend：

```bash
pulumi whoami -v
```

退出当前 Backend：

```bash
pulumi logout
```

退出所有 Backend：

```bash
pulumi logout --all
```

登录信息会写入 `~/.pulumi/credentials.json`。如果要减少每次手工输入 URL 的频率，官方文档给出两种常用方式：

```bash
export PULUMI_BACKEND_URL=<backend-url>
```

或在 `Pulumi.yaml` 中写入：

```yaml
backend:
  url: <backend-url>
```

项目文件中的 `backend.url` 很适合团队约定同一个项目应该使用哪个 Backend。环境变量适合 CI 或一次性命令。两者都只是告诉 CLI 去哪里找 State，不会替你提供云存储的访问权限。

## 2B.4 DIY Backend 的 URL 形态

DIY Backend 使用 URL 表示目标存储位置。常见格式如下：

| Backend | URL 示例 | 说明 |
|---------|----------|------|
| 本地文件系统 | `file:///app/data` | State 存在本机目录下的 `.pulumi` 子目录 |
| AWS S3 | `s3://my-pulumi-state-bucket` | State 存入 S3 bucket，可带路径前缀 |
| Azure Blob | `azblob://my-container` | State 存入 Azure Blob container |
| Google Cloud Storage | `gs://my-pulumi-state-bucket` | State 存入 GCS bucket |
| PostgreSQL | `postgres://user:pass@host:5432/db` | State 存入 PostgreSQL |

本地 Backend 有一个简写：

```bash
pulumi login --local
```

它等价于：

```bash
pulumi login file://~
```

S3 Backend 的基础形式是：

```bash
pulumi login s3://my-pulumi-state-bucket
```

官方文档建议在需要指定 region、profile 或 AWS SDK v2 时，把参数放在 query string 中，并用引号保护 URL：

```bash
pulumi login 's3://my-pulumi-state-bucket?region=us-east-1&awssdk=v2&profile=dev'
```

如果目标是 S3 兼容服务，例如 Minio、Ceph 或本教程实验中的 MiniStack，可以指定 endpoint、禁用 HTTPS，并启用 path-style：

```bash
pulumi login 's3://my-pulumi-state-bucket?endpoint=localhost:4566&disableSSL=true&s3ForcePathStyle=true&region=us-east-1&awssdk=v2'
```

Azure Blob Backend 的基础形式是：

```bash
pulumi login azblob://my-container
```

它通过 Azure SDK for Go 使用 Azure Blob Storage。常用认证方式包括：

| 方式 | 需要的设置 | 说明 |
|------|------------|------|
| 账号密钥 | `AZURE_STORAGE_ACCOUNT` 与 `AZURE_STORAGE_KEY` | 适合简单脚本和本地实验 |
| SAS token | `AZURE_STORAGE_ACCOUNT` 与 `AZURE_STORAGE_SAS_TOKEN` | 适合限制权限和有效期 |
| Azure SDK 默认凭据 | `AZURE_CLIENT_ID` 等或 Azure CLI 登录 | 适合真实 Azure 环境中的服务主体、托管身份或工作负载身份 |

注意 Azure Blob Backend 使用的是 Azure SDK 的认证链，不是 Pulumi Azure provider 的认证配置。换句话说，`ARM_CLIENT_ID`、`ARM_TENANT_ID` 这类 provider 变量不能替代 `AZURE_STORAGE_*` 或 Azure SDK 默认凭据。

官方文档还说明，从 Pulumi CLI v3.41.1 开始，可以在 URL 中指定 storage account：

```bash
pulumi login 'azblob://my-container?storage_account=account_name'
```

本章 Azure 实验会用 azlocal 创建和查看 miniblue 中的 Blob container；Pulumi CLI 登录 `azblob://` Backend 时，还会在 Backend URL 中加入 local emulator 参数，例如 `protocol` 与 `domain`。这是本地模拟器适配方式；真实 Azure 环境通常不需要这两个参数。

真实 Azure 中，访问该 container 的身份需要具备读、写、删除 blob 的权限。常见选择是 Storage Blob Data Contributor 或等价权限。

## 2B.5 DIY Backend 的目录结构

Pulumi 在 DIY Backend 中会创建一个 `.pulumi` 目录。以新建的 project-scoped Backend 为例，里面通常包含：

| 路径 | 用途 |
|------|------|
| `.pulumi/meta.yaml` | Backend 元数据，不保存具体 Stack 资源 |
| `.pulumi/stacks/<project>/<stack>.json` | 当前 Stack 的最新 checkpoint |
| `.pulumi/locks/<project>/<stack>/...` | 更新进行中时的锁文件 |
| `.pulumi/history/<project>/<stack>/...` | 历史 checkpoint 记录 |

早期 Pulumi 版本中的 DIY Backend 使用全局 Stack 命名空间。Pulumi v3.61.0 之后，新建或空的 DIY Backend 默认按 Project 组织 Stack，所以多个 Project 可以在同一个 Backend 中都使用 `dev`、`prod` 这样的 Stack 名。

如果旧 Backend 仍处于全局命名空间，官方提供 `pulumi state upgrade` 来升级到 project-scoped 格式。这个操作不可回退，并且升级后的 Stack 不能再被旧版 Pulumi CLI 访问，所以执行前要确认团队 CLI 版本已经统一。

## 2B.6 锁、历史与可靠性边界

Pulumi 更新 Stack 时必须避免两个进程同时写同一份 State。DIY Backend 默认启用基于文件的锁机制：更新开始时写入 lock 文件，更新结束后删除 lock 文件。对象存储 Backend 还会保留 history 目录，用于记录 checkpoint 历史。

这并不等于 DIY Backend 与 Pulumi Cloud 在所有故障场景下完全相同。Pulumi Cloud 通过事务化 API 写入 checkpoint，更适合多人长期协作，并提供审计、权限和历史视图。对象存储 Backend 依赖底层 blob 协议，遇到网络中断或部分失败时，需要你具备排障与恢复流程。

生产实践中，使用 DIY Backend 至少要明确这些事项：

- State bucket 或 container 必须开启备份、版本保留或对象保护策略。
- 读写权限应限制到执行 Pulumi 的人和 CI 身份。
- Secret 加密 provider 要统一，并保存好相关密钥材料。
- Backend URL 应进入项目规范或 CI 变量，不要靠个人口头约定。
- 出现 lock 残留时，应先确认没有仍在运行的更新，再处理锁文件。

## 2B.7 Refresh：State 不会自动核对真实云资源

::: warning 注意：这里与 Terraform 不一样
如果你熟悉 Terraform，要特别注意这个差异：Terraform 常见的 `plan` / `apply` 工作流默认会先 refresh 状态（除非显式关闭），而 Pulumi 的 `preview` / `up` 默认不会先把云端真实状态读回 State。

所以在 Pulumi 中，如果怀疑有人通过云控制台、云 CLI 或其他工具改过资源，需要主动运行 `pulumi refresh`，或给 `preview` / `up` 加 `--refresh`。
:::

Pulumi 的 `preview` 与 `up` 默认比较的是程序目标状态和当前 State。它不会在每次操作前都访问云 provider，把每个资源的真实状态全部核对一遍。

如果有人在云控制台或其他工具里改了资源，State 可能变旧。此时可以显式执行：

```bash
pulumi refresh
```

`pulumi refresh` 会读取云端真实资源，并把差异写回 State。它只更新 State，不会改你的 Pulumi 程序。

也可以在更新前先 refresh：

```bash
pulumi up --refresh
```

或在预览前先 refresh：

```bash
pulumi preview --refresh
```

是否 refresh 是一个有成本的选择。大型 Stack 中逐一读取云资源会明显增加时间；另一方面，如果你怀疑有人在 Pulumi 之外改过资源，refresh 能让下一次 diff 更可信。

## 2B.8 导出、导入与 Backend 切换

`pulumi stack export` 可以把当前 Stack 的 State 导出为 JSON 文件：

```bash
pulumi stack export --file dev.stack.json
```

`pulumi stack import` 可以把 JSON 文件写回当前 Stack：

```bash
pulumi stack import --file dev.stack.json
```

这两个命令常用于诊断、备份验证、受控修复，以及把 Stack 从一个 Backend 转到另一个 Backend。官方文档强调：Stack State 里包含 Backend 相关元数据和加密 provider 信息，所以不能简单复制对象存储里的 JSON 文件来完成 Backend 切换。正确方式是通过 export 与 import 让 Pulumi CLI 处理必要转换。

一个典型流程是：

```bash
pulumi login <old-backend-url>
pulumi stack select dev
pulumi stack export --show-secrets --file dev.stack.json

pulumi logout
pulumi login <new-backend-url>
pulumi stack init dev
pulumi stack import --file dev.stack.json
```

如果导出时使用 `--show-secrets`，文件中会出现解密后的敏感值。这个文件应按高敏感材料处理，完成后及时删除或放入受控密钥系统。

## 2B.9 常见故障与排查方向

官方 DIY Backend 文档中最常见的错误之一，是读取 `.pulumi/meta.yaml` 失败。这个错误通常不是 meta 文件损坏，而是 CLI 到达了存储服务，却无法完成认证或授权。

常见原因包括：

| 现象 | 可能原因 | 检查方向 |
|------|----------|----------|
| S3 报 MissingRegion | AWS SDK 找不到 region | 在 URL 中加 `region=...` 或设置 `AWS_REGION` |
| S3 报 AccessDenied | 身份没有 bucket 权限 | 检查 bucket policy、IAM policy、临时凭据有效期 |
| Azure Blob 报权限不足 | 身份不能读写 blob | 检查 Storage Blob Data Contributor 或 SAS 权限 |
| Azure Blob 使用 ARM 变量仍失败 | Backend 不读 `ARM_*` | 改用 `AZURE_STORAGE_*` 或 Azure SDK 默认凭据 |
| 团队成员看不到 Stack | Backend 命名空间或 URL 不一致 | 用 `pulumi whoami -v` 比对 Backend URL |

排查时先执行：

```bash
pulumi whoami -v
```

再确认本机或 CI 中的存储访问环境变量。需要更详细日志时，可以使用 CLI verbose logging，例如：

```bash
pulumi -v=9 stack ls
```

## 小结

- State 是 Stack 的事实记录，Backend 是保存 State 的端点。
- Backend 凭据与 provider 凭据是两套权限。
- Pulumi Cloud 是默认 Backend，DIY Backend 适合自管理 State 的 OSS 场景。
- S3、Azure Blob、GCS、PostgreSQL 和本地文件系统都有对应 URL 格式。
- DIY Backend 使用 `.pulumi` 目录保存 meta、stacks、locks 和 history。
- `refresh` 用来显式核对真实云资源，`export` 和 `import` 用来处理 State 文件。
- 自管理 Backend 要认真设计备份、权限、加密和故障处理流程。

## 动手实验

下面两个实验使用本地模拟器，不需要真实 AWS 或 Azure 账号。它们的 Pulumi 程序都只创建一个很小的随机资源，重点是观察 State 如何写入不同 Backend。

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-state-backends-aws" title="实验：State 与 Backend（AWS / MiniStack）" desc="使用 MiniStack 提供 S3 兼容对象存储，练习 pulumi login 到 s3:// DIY Backend、创建 Stack、观察 .pulumi/meta.yaml 与 stacks/history 路径、导出导入 State，并区分 Backend 凭据与 provider 凭据。" />

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-state-backends-azure" title="实验：State 与 Backend（Azure / miniblue）" desc="使用 miniblue 提供 Azure Blob 风格存储，练习 azblob:// DIY Backend、AZURE_STORAGE_* 凭据、project backend.url、Stack checkpoint 路径、State export/import 与 Backend 排障。" />