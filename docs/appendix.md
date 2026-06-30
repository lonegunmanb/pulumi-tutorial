---
order: 90
title: 附录与速查表
group: 附录
---

# 附录与速查表

这份附录不是新的概念章节，而是读完全书后回查用的工作台。前面的章节按学习顺序展开；附录按“我现在遇到什么问题”重新组织：要查命令、定位概念、判断风险、选择章节或实验时，可以先从这里进入。

本教程坚持 Pulumi OSS 范围：Pulumi CLI、语言 SDK、本地或自管理 Backend、Automation API、本地 Policy Pack、通用 CI，以及 MiniStack 与 MiniBlue 这样的本地模拟器。Pulumi Cloud、ESC、Deployments、云端策略托管和托管协作能力只作为边界说明，不作为实验前提。

## A. 按问题回到章节

| 现在要解决的问题 | 先回看 | 重点 |
|---|---|---|
| 不清楚 `preview`、`up`、Engine、Provider 和 State 的关系 | [架构解析](architecture.md)、[Pulumi 是如何工作的](how-pulumi-works.md) | 程序执行、资源注册、变更计划、状态记录 |
| 不知道 Project、Stack、Backend、配置文件分别管什么 | [项目、堆栈与状态管理](projects-stacks-state.md)、[Stack 详解](stacks.md)、[State 与 Backend](state_backends.md) | `Pulumi.yaml`、`Pulumi.<stack>.yaml`、Backend URL、状态文件 |
| 需要设置环境差异、普通配置或机密配置 | [Configuration 配置](configs.md)、[Secrets 机密处理](secrets-handling.md)、[多环境 Stack 配置与动态基础设施](dynamic-stacks.md) | 命名空间、结构化配置、Secret、项目默认值与 Stack 覆盖 |
| 看不懂 `Output<T>`，或者想把一个资源输出传给另一个资源 | [Inputs, Outputs](inputs-outputs.md) | `apply`、`all`、`interpolate`、自动依赖、不要在 `apply` 里创建资源 |
| 资源改名、替换、保护、忽略漂移或显式依赖 | [资源与精细控制](resources.md)、[企业级架构：Components](components.md) | URN、逻辑名、aliases、protect、ignoreChanges、dependsOn、parent |
| Provider 认证、显式 provider、本地模拟器或 Terraform provider | [Provider 抽象](providers.md)、[使用 Terraform Module](terraform-modules.md) | default provider、explicit provider、dynamic provider、Any Terraform Provider、Terraform Module provider |
| 想封装可复用基础设施能力 | [企业级架构：Components](components.md)、[Pulumi Templates](templates.md)、[Component 包分发与基于 Git 的版本化引用](component-packaging-git.md) | ComponentResource、模板、source-based package、native language package |
| 想把已有 Terraform Module 接入 Pulumi | [使用 Terraform Module](terraform-modules.md) | `pulumi package add terraform-module`、本地 SDK、模块输出、内部 state 与限制 |
| 想把 Pulumi 嵌入平台后端或测试框架 | [Automation API](automation-api.md)、[测试驱动开发与 CI/CD 实践](testing.md) | LocalWorkspace、Stack API、事件流、临时 Stack、集成测试 |
| 想在变更前运行规则检查 | [Policy as Code](policy-as-code.md)、[最佳实践](best-practices.md) | 本地 Policy Pack、advisory、mandatory、策略配置 |
| 更新失败、状态异常、CI 失败或真实资源漂移 | [Pulumi 调试与故障排查](debugging.md)、[State 与 Backend](state_backends.md) | `--diff`、`--debug`、verbose 日志、refresh、state export/import |

## B. CLI 速查表

### 项目、Stack 与 Backend

| 场景 | 命令 | 注意 |
|---|---|---|
| 查看 CLI 版本 | `pulumi version` | 安装后第一步验证 |
| 使用本地 Backend | `pulumi login --local` | 实验常用；团队协作要评估自管理 Backend 或 Pulumi Cloud |
| 使用自管理 Backend | `pulumi login <backend-url>` | Backend 凭据和云 Provider 凭据是两套权限 |
| 创建 Stack | `pulumi stack init dev` | Stack 名称应能表达环境或用途 |
| 选择 Stack | `pulumi stack select dev` | 命令会影响后续 config、preview、up |
| 查看 Stack | `pulumi stack ls` | 可确认当前 Project 下有哪些 Stack |
| 删除空 Stack | `pulumi stack rm dev` | 先确认资源已经销毁或不需要继续由该 Stack 管理 |

### 变更与生命周期

| 场景 | 命令 | 注意 |
|---|---|---|
| 预览变更 | `pulumi preview --diff` | 真实变更前优先看 diff |
| 执行变更 | `pulumi up` | 交互式确认适合本地；CI 通常加 `--yes --non-interactive` |
| 创建或更新时同步真实状态 | `pulumi up --refresh` | 适合怀疑真实资源被手工改动的场景 |
| 只刷新状态 | `pulumi refresh` | 会写回 State，不会改程序代码 |
| 只查看刷新计划 | `pulumi refresh --preview-only --diff` | 排查漂移时更稳妥 |
| 删除 Stack 内资源 | `pulumi destroy` | 删除的是当前 Stack 管理的资源，不等于删除项目目录 |
| 显示 URN | `pulumi stack --show-urns` | 做定向操作、aliases 排查和 state 修复时常用 |

### 配置与机密

| 场景 | 命令 | 注意 |
|---|---|---|
| 设置普通配置 | `pulumi config set app:replicas 2` | 带冒号的是命名空间；不带时默认使用项目名 |
| 读取配置 | `pulumi config get app:replicas` | 不存在时返回空结果；程序里可用 `require` 强制要求 |
| 设置机密配置 | `pulumi config set dbPassword --secret` | 程序里应使用 `requireSecret` 或 `getSecret` |
| 写结构化配置 | `pulumi config set --path settings.subnets[0].name web` | 适合对象、数组和嵌套值 |
| 查看全部配置 | `pulumi config` | 默认不会显示 Secret 明文 |
| 查看含明文的配置或输出 | `--show-secrets` | 只能在受控终端使用，结果不要提交到 Git |

### 状态、策略与包

| 场景 | 命令 | 注意 |
|---|---|---|
| 导出 State | `pulumi stack export --file state.json` | 做 state 修复前先导出备份 |
| 导出含 Secret 明文的 State | `pulumi stack export --show-secrets --file state.json` | 只在确有需要时使用，文件需要单独保护 |
| 导入 State | `pulumi stack import --file state.json` | 导入前先确认当前 Backend 和 Stack |
| 查看 state 子命令 | `pulumi state --help` | 修复类命令要先备份 State |
| 本地运行策略 | `pulumi preview --policy-pack ../policy-pack` | resource policy 可以在 preview 阶段给出反馈 |
| 添加 Terraform provider 包 | `pulumi package add terraform-provider <source> <name>` | 用于接入单个 Terraform provider 的资源类型 |
| 添加 Terraform Module 包 | `pulumi package add terraform-module <source> [version] <name>` | 用于把已有 Terraform Module 当作 Pulumi package 消费 |
| 从模板创建项目 | `pulumi new <template>` | 模板目录外执行本地模板测试更清晰 |

## C. State 与变更安全顺序

Pulumi 的日常工作可以按以下顺序处理。

1. 修改代码、配置或组件版本。
2. 运行 `pulumi preview --diff`，先看资源数量、操作符和关键属性。
3. 如果涉及真实环境、多人协作或删除动作，先导出状态：`pulumi stack export --file before-change.json`。
4. 计划符合预期后执行 `pulumi up`。
5. 如果怀疑真实资源被外部改动，先用 `pulumi refresh --preview-only --diff` 观察，再决定是否刷新状态。
6. 如果需要修复 State，先备份，再使用 `pulumi state` 或 `pulumi stack import`，并记录修改原因。

常见判断如下。

| 信号 | 可能含义 | 推荐动作 |
|---|---|---|
| preview 显示大量 replace | 逻辑名、物理名、provider、输入属性或组件父子关系发生变化 | 先检查 URN、aliases、provider 和 diff |
| 真实资源已手工修改 | State 与真实环境不一致 | 先运行 refresh 预览，再决定接受真实状态还是让代码恢复目标状态 |
| State 里有 pending operations | 上次更新中断 | 先导出 State，再参考调试章节处理 |
| Secret 明文出现在导出文件 | 使用了 `--show-secrets` | 立即保护文件，不要提交到版本库 |
| Backend 访问失败 | Backend 凭据、网络或 URL 参数错误 | 先查 Backend 登录状态，再查云 Provider 凭据 |

## D. 配置、Outputs 与 Secrets 判断表

| 需求 | 优先使用 | 回看章节 |
|---|---|---|
| 同一项目在 dev、prod 使用不同参数 | Stack Config | [Configuration 配置](configs.md)、[多环境 Stack 配置与动态基础设施](dynamic-stacks.md) |
| 所有 Stack 共享默认值 | `Pulumi.yaml` 的项目级配置 | [Configuration 配置](configs.md) |
| 值不能以明文保存 | Secret Config 或 `pulumi.secret` | [Secrets 机密处理](secrets-handling.md) |
| 从一个资源输出拼接另一个资源输入 | `interpolate`、`concat` 或 `apply` | [Inputs, Outputs](inputs-outputs.md) |
| 同时等待多个输出值 | `all` | [Inputs, Outputs](inputs-outputs.md) |
| 跨 Project 读取上游结果 | `StackReference` | [项目、堆栈与状态管理](projects-stacks-state.md)、[最佳实践](best-practices.md) |
| 保存一次部署时产生的小段数据 | `pulumi:index:Stash` | [Stash 状态暂存](stash.md) |
| 把文件、目录或代码包交给资源输入 | Asset 或 Archive | [Assets 与 Archives](assets_archives.md) |

两条经验最值得反复提醒：第一，`Output` 是未来才知道的值，不要把它当普通字符串同步读取；第二，Secret 的机密性会沿 Output 传播，显示、导出和日志输出都要按敏感数据处理。

## E. Resource Option 速查

| 选项 | 适用场景 | 注意 |
|---|---|---|
| `dependsOn` | 两个资源没有属性连接，但真实平台要求顺序 | 优先让 Output→Input 自动建立依赖，显式依赖只处理隐含顺序 |
| `parent` | 把子资源挂到组件或上级资源下 | 会影响 URN，组件演进时要谨慎 |
| `provider` | 某个 CustomResource 使用指定 provider | 单一 provider 选项，常用于多区域、多账号或本地模拟器 |
| `providers` | ComponentResource 把 provider 传给内部子资源 | 组件要显式读取并转交给子资源 |
| `aliases` | 资源逻辑名、类型或父级变化后仍保留原资源 | 重命名前先 preview，确认不是 delete/create |
| `protect` | 防止误删关键资源 | 删除前要先移除保护并完成一次更新 |
| `ignoreChanges` | 真实平台会改写某些属性，且代码不应每次改回 | 只忽略确认可接受的字段，避免掩盖重要漂移 |
| `deleteBeforeReplace` | 新旧资源不能同时存在 | 会先删旧资源，可能带来中断 |
| `replaceOnChanges` | 指定属性变化时强制替换 | 适合 provider 无法准确判断替换边界的资源 |
| `customTimeouts` | 创建、更新或删除时间较长 | 只改变等待时间，不改变云 API 行为 |
| `retainOnDelete` | 从 State 移除但保留真实资源 | 后续谁管理该资源要提前说明 |

Terraform Module provider 的内部 resource views 不是普通 Pulumi 子资源。它们能帮助观察模块内部变化，但不能像普通资源那样逐个使用 transforms、target 或 protect；可控边界主要是外层 Module 调用。

## F. Provider、Package 与复用路径

| 目标 | 优先路径 | 适合情况 | 章节 |
|---|---|---|---|
| 使用官方支持的云资源 | 官方 Pulumi provider | AWS、Azure、Kubernetes 等常见资源 | [Provider 抽象](providers.md) |
| 使用未进入官方 Pulumi provider 的 Terraform provider | Any Terraform Provider | 需要直接创建某个 Terraform provider 资源类型 | [Provider 抽象](providers.md) |
| 使用已有 Terraform Module | Terraform Module provider | 团队已有成熟 Module，想在 Pulumi 中调用并读取输出 | [使用 Terraform Module](terraform-modules.md) |
| 封装一组资源给同语言项目 | Native language package | 团队主要使用同一种语言 | [Component 包分发与基于 Git 的版本化引用](component-packaging-git.md) |
| 封装一组资源给多语言项目 | Source-based plugin package | 想通过 `pulumi package add` 在消费者侧生成 SDK | [Component 包分发与基于 Git 的版本化引用](component-packaging-git.md) |
| 编写自定义 CRUD | Dynamic Provider | 资源逻辑很小，且只在当前语言项目内使用 | [Provider 抽象](providers.md) |
| 给新项目统一起点 | Pulumi Template | 目录结构、依赖、配置提示和 README 需要统一 | [Pulumi Templates](templates.md) |

## G. 实验环境索引

| 实验环境 | 本教程中的用途 | 注意 |
|---|---|---|
| MiniStack | AWS 风格资源实验，例如 S3、VPC、RDS、Policy、Testing | 使用本地 endpoint，不需要真实 AWS 凭据 |
| MiniBlue | Azure 风格资源实验，例如 Resource Group、VNet、Storage、Blob Backend | HTTPS metadata endpoint 使用自签名证书，初始化脚本会加入信任链 |
| 本地 Backend | 大多数实验默认状态后端 | 适合学习与单机实验，不代表团队协作的完整方案 |
| S3 兼容 Backend | State 与 Backend AWS 实验 | Backend 权限和 Provider 权限分开检查 |
| Azure Blob 风格 Backend | State 与 Backend Azure 实验 | Backend URL 中可能包含本地模拟器参数 |
| 本地 Git 仓库 | Templates 与 Component package 实验 | 用 tag、commit 或路径模拟真实仓库分发 |
| `act` | CI/CD 实验 | 用 Docker 在本地模拟 GitHub Actions 运行环境 |

实验脚本遵循一个约定：模拟器启动、证书信任、基础目录和示例项目准备放在 `init/background.sh`；学习者在 `step*/text.md` 中执行的命令只保留教学操作。这样每个实验页面的重点都落在 Pulumi 行为本身。

## H. 排障路径速查

| 症状 | 先检查 | 常用命令 |
|---|---|---|
| 程序编译或运行报错 | 语言栈、依赖、入口文件和行号 | `npm test`、`pulumi preview` |
| 缺配置或配置类型错误 | 当前 Stack、配置命名空间、`Pulumi.<stack>.yaml` | `pulumi stack`、`pulumi config` |
| Secret 解密失败 | Backend、passphrase、secret provider | `pulumi config --show-secrets` 只在受控环境使用 |
| Provider 认证失败 | 云凭据、region、endpoint、显式 provider | `pulumi up --logtostderr --logflow -v=9` |
| preview 出现意外 replace | URN、逻辑名、parent、provider、aliases | `pulumi preview --diff --show-replacement-steps` |
| 真实资源与代码不一致 | 控制台外改动、自动补全属性、provider read 结果 | `pulumi refresh --preview-only --diff` |
| 更新中断或状态异常 | pending operations、State 备份、Backend 锁 | `pulumi stack export --file state.json` |
| CI 里失败但本地正常 | 工作目录、环境变量、依赖安装、Stack 名称、非交互参数 | `pulumi preview --non-interactive --diff` |
| Terraform Module 失败 | OpenTofu/Terraform 执行器、模块 provider 配置、生成 SDK、内部 state | `pulumi package add terraform-module ...`、`pulumi stack export` |

排障顺序建议从低成本信息开始：先看 `preview --diff` 和配置，再看 Provider 诊断；怀疑真实资源变化时再 refresh；只有确认是 State 层面的问题，才进入 state 修复。

## I. 真实环境变更前检查

把实验带到真实账号或团队环境前，至少确认以下事项。

| 检查项 | 要确认的问题 |
|---|---|
| Backend | State 存在哪里，谁有读写权限，是否有备份和锁语义 |
| 云凭据 | Provider 使用哪套身份，权限是否最小化，凭据是否由安全渠道注入 |
| Stack 命名 | Stack 名称能否唯一表示环境、区域、账号或工作负载 |
| 配置 | 普通配置、Secret、项目默认值和 Stack 覆盖是否分层清晰 |
| Preview | 每次合并前是否能看到 `pulumi preview --diff` 结果 |
| 策略 | 是否用本地 Policy Pack 检查标签、公开访问、规格和数量上限 |
| 组件 | 安全默认值是否集中在组件里，调用方输入是否受限 |
| State 备份 | 大变更前是否导出 State，备份文件是否受保护 |
| 漂移检测 | 是否定期运行 refresh 预览或在关键变更前加 `--refresh` |
| 清理责任 | 临时 Stack、测试资源和失败更新后的残留资源由谁处理 |

## J. 术语表

| 术语 | 含义 | 回看章节 |
|---|---|---|
| Project | 一个 Pulumi 程序目录，通常包含 `Pulumi.yaml`、入口代码和依赖文件 | [项目、堆栈与状态管理](projects-stacks-state.md) |
| Stack | 同一个 Project 的一个独立实例，拥有自己的配置、输出和 State | [Stack 详解](stacks.md) |
| State | Pulumi 保存的资源登记簿，记录 URN、ID、输入、输出、依赖和 Secret 元数据 | [State 与 Backend](state_backends.md) |
| Backend | 保存 State 的位置，可以是 Pulumi Cloud、本地文件、自管理对象存储或数据库 | [State 与 Backend](state_backends.md) |
| URN | Pulumi 资源的逻辑身份，包含 Stack、Project、类型、父子关系和逻辑名 | [资源与精细控制](resources.md) |
| CustomResource | 对应真实云资源或 provider 管理对象的资源 | [资源与精细控制](resources.md) |
| ComponentResource | 只在 Pulumi 资源图中分组和封装子资源的组件资源 | [企业级架构：Components](components.md) |
| Provider | 把 Pulumi 资源操作翻译成云 API 或本地 API 调用的插件和配置对象 | [Provider 抽象](providers.md) |
| Input | 资源属性可以接收的输入类型，既可以是普通值，也可以是未来才知道的值 | [Inputs, Outputs](inputs-outputs.md) |
| Output | 资源创建或读取后才得到的值，同时携带依赖和 Secret 信息 | [Inputs, Outputs](inputs-outputs.md) |
| Secret | 被 Pulumi 标记为敏感的数据，写入 State 时会加密或隐藏 | [Secrets 机密处理](secrets-handling.md) |
| StackReference | 从另一个 Stack 读取输出的资源 | [最佳实践](best-practices.md) |
| Policy Pack | 一组可执行策略，用于在 preview 或 up 阶段检查资源属性 | [Policy as Code](policy-as-code.md) |
| Automation API | 用语言 SDK 控制 Stack 生命周期的 API | [Automation API](automation-api.md) |
| Pulumi Package | 可被语言 SDK 消费的资源或组件包，可以来自官方 provider、插件或生成 SDK | [Component 包分发与基于 Git 的版本化引用](component-packaging-git.md) |
| Terraform Module provider | 让 Pulumi 调用 Terraform Module 并生成本地 SDK 的 provider | [使用 Terraform Module](terraform-modules.md) |
| Stash | Pulumi 内置的状态暂存资源，用于保存少量部署时数据 | [Stash 状态暂存](stash.md) |
| Asset | 单个文件、字符串或远端内容作为资源输入 | [Assets 与 Archives](assets_archives.md) |
| Archive | 文件集合或压缩包作为资源输入 | [Assets 与 Archives](assets_archives.md) |

## K. 后续维护约定

- 新增章节后，同步更新“A. 按问题回到章节”和“J. 术语表”。
- 新增实验后，同步更新“G. 实验环境索引”，并说明是否需要真实云凭据。
- 新增危险命令时，必须同时写明 preview、备份和恢复步骤。
- 涉及 Secret、State 导出或真实云账号时，必须写清楚文件保护、权限边界和清理责任。
- 命令速查只放高频命令；长流程仍放在对应章节，附录只提供入口。