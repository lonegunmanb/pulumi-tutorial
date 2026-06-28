---
order: 65
title: Pulumi Templates
group: 第 3 篇：Pulumi OSS 工程化扩展与交付实践
---

# Pulumi Templates

## 本章定位

前面的章节已经讲过 Project、Stack、Config、ComponentResource、Automation API 和 Packages。它们分别回答了“一个 Pulumi 程序如何运行”“一个环境如何隔离”“一组资源如何复用”“平台如何调用 Pulumi”等问题。本章讨论更靠前的一步：**一个新项目从哪里开始**。

Pulumi Template 是 `pulumi new` 可以被执行的项目脚手架。它把 `Pulumi.yaml`、程序入口、依赖文件、README 和需要询问使用者的配置项放在一个目录里。使用者运行 `pulumi new <template>` 时，Pulumi 会复制模板文件，询问项目名、描述和模板声明的配置值，然后生成一个可运行的新 Pulumi Project。

本章聚焦 Pulumi OSS 能独立完成的能力：本地模板目录、Git 仓库模板、Git 分支或 tag、多模板仓库、`Pulumi.yaml` 的 `template` 段、配置默认值与机密配置。官方文档中的 Organization Templates 与 Private Registry 适合集中管理模板，但依赖 Pulumi Cloud 的组织能力，本教程只说明边界，不把它作为实验前提。

## 官方映射

- [Creating Pulumi templates](https://www.pulumi.com/docs/iac/guides/building-extending/creating-templates/)：模板目录结构、`Pulumi.yaml` 的 `template` 段、变量替换、Git 仓库使用、私有仓库认证、本地测试、共享方式和最佳实践。
- [Project file reference](https://www.pulumi.com/docs/iac/concepts/projects/project-file/)：`Pulumi.yaml` 项目文件的完整字段说明，包括模板相关字段。
- [pulumi new](https://www.pulumi.com/docs/iac/cli/commands/pulumi_new/)：`pulumi new` 命令参数、模板来源和项目创建流程。

## 8.1 Template 解决的问题：让新项目从标准起点开始

没有模板时，新服务通常从复制旧项目开始。复制旧项目看似直接，但很容易把旧服务的命名、配置、Provider 版本、README、测试命令和临时注释也复制过去。时间久了，每个项目都略有差异，平台团队很难判断哪些差异是业务需要，哪些只是起点不一致。

Template 的目标不是生成所有基础设施，而是给新项目一个被审查过的起点：目录结构一致、依赖版本一致、配置键清楚、机密配置被标注、README 说明完整、示例程序能立即 preview。

![Pulumi Template 像一套项目开箱工具](./images/templates-scaffold-kit.png)

Template 与 Component、Package 的边界也要分清：

| 能力 | 解决的问题 | 结果 |
|------|------------|------|
| Template | 新 Project 如何开始 | 生成一份项目文件 |
| Component | 一组资源如何复用 | 在程序里创建资源树 |
| Package | 可复用能力如何跨项目/语言分发 | 提供可安装的 SDK 或插件 |

一个成熟团队通常会把三者组合起来：Template 生成项目骨架，骨架里预置组件调用样例，依赖里固定内部 [Package](./packages.md) 版本。这样新服务不需要从空目录开始，也不需要直接面对底层云资源的全部参数。

## 8.2 Template 的基本目录结构

官方文档给出的基本结构非常小：

```text
my-template/
├── Pulumi.yaml
├── index.ts
├── package.json
└── README.md
```

不同语言会有不同入口文件。例如 Python 常见 `__main__.py`，Go 常见 `main.go`，.NET 和 Java 还会有各自的项目文件。本章用 TypeScript 举例，因为本教程大多数实验都使用 Node.js 生态。

一个最小 TypeScript 模板可以这样组织：

```text
service-template/
├── Pulumi.yaml
├── index.ts
├── package.json
├── tsconfig.json
└── README.md
```

每个文件的职责如下：

| 文件 | 职责 |
|------|------|
| `Pulumi.yaml` | 定义 Project 元数据、runtime 和 template 配置提示 |
| `index.ts` | 新项目的 Pulumi 程序入口 |
| `package.json` | 语言依赖与脚本 |
| `tsconfig.json` | TypeScript 编译设置 |
| `README.md` | 说明模板创建什么、需要哪些配置、如何 preview/up/destroy |

Template 目录可以包含更多文件，例如 `policy-pack/`、`src/components/`、`tests/`、`.github/workflows/` 或 `.env.example`。关键原则是：模板生成的项目应当可以被普通开发者理解和维护，而不是只为模板作者服务。

## 8.3 Pulumi.yaml：template 段是识别模板的关键

官方文档指出，`Pulumi.yaml` 必须包含 `template` 段，才会被识别为有效模板。下面是一个简化示例：

```yaml
name: ${PROJECT}
runtime: nodejs
description: ${DESCRIPTION}
template:
  displayName: Service Infrastructure
  description: A TypeScript template for a service infrastructure project
  quickstart: Run npm install to install dependencies, then pulumi up to deploy.
  important: false
  config:
    aws:region:
      description: The AWS region to deploy into
      default: us-east-1
    serviceName:
      description: The service name used in resource naming and tags
    owner:
      description: The team or person responsible for this stack
      default: platform-team
    dbPassword:
      description: The database password for tutorial examples
      secret: true
  metadata:
    cloud: aws
    category: service
```

`template` 段常用字段如下：

| 字段 | 说明 |
|------|------|
| `displayName` | 在模板列表中展示的友好名称 |
| `description` | 模板创建内容的简要说明 |
| `quickstart` | `pulumi new` 生成项目后展示的后续步骤说明 |
| `important` | 是否将模板标记为重要模板，用于模板列表展示 |
| `config` | 运行 `pulumi new` 时要询问的配置项 |
| `metadata` | 用于分类的自定义键值对 |

每个 `config` 项还可以声明这些属性：

| 属性 | 说明 |
|------|------|
| `description` | 告诉使用者这个值用于什么 |
| `default` | 提供默认值，使用者可以接受或覆盖 |
| `secret` | 设为 `true` 时，将该配置作为机密值写入 |

这里有三个实践细节值得注意。第一，云 Provider 的配置也可以放进 `template.config`，例如 `aws:region`。这能让新项目一开始就有清楚的区域选择。第二，敏感配置应当标成 `secret: true`，不要只靠 README 提醒使用者手动加 `--secret`。第三，`quickstart` 很适合写下一步命令，例如安装依赖、设置环境变量或执行 `pulumi preview`。

## 8.4 变量替换：PROJECT 与 DESCRIPTION

Template 支持在任意文件中使用两个占位变量：

| 变量 | 含义 |
|------|------|
| `${PROJECT}` | 使用者在 `pulumi new` 中输入的项目名 |
| `${DESCRIPTION}` | 使用者在 `pulumi new` 中输入的项目描述 |

最常见的用法是在 `Pulumi.yaml` 中写：

```yaml
name: ${PROJECT}
description: ${DESCRIPTION}
```

也可以在 README 中使用：

````markdown
# ${PROJECT}

${DESCRIPTION}

## 常用命令

```bash
pulumi preview
pulumi up
```
````

变量替换不是通用模板语言。它不会帮你根据条件生成不同代码，也不会循环展开资源声明。复杂逻辑应该放在 Pulumi 程序、组件或脚手架外层工具里，而不是期待 Template 自身变成代码生成系统。

## 8.5 通过 Git 仓库使用 Template

`pulumi new` 可以直接消费 Git 仓库 URL。公开仓库的常见写法如下：

```bash
pulumi new https://github.com/myorg/my-template
pulumi new https://gitlab.com/myorg/my-template
pulumi new https://bitbucket.org/myorg/my-template
pulumi new https://git.example.com/myorg/my-template.git
```

如果模板位于仓库子目录，可以使用带 `tree` 的 URL：

```bash
pulumi new https://github.com/myorg/templates/tree/main/aws-typescript
```

如果需要固定分支或 tag，也可以这样写：

```bash
pulumi new https://github.com/myorg/my-template/tree/develop
pulumi new https://github.com/myorg/my-template/tree/v1.0.0
```

这让团队可以把模板和普通代码一样用 Git 管理：通过 Pull Request 审查模板变化，通过 tag 提供稳定版本，通过子目录组织多个模板。

对于 GitLab 中包含 subgroup 的仓库，官方文档建议在 URL 后保留 `.git`，用于消除路径歧义：

```bash
pulumi new https://gitlab.com/mygroup/mysubgroup/my-template.git
```

## 8.6 私有仓库认证：优先使用 SSH 或凭据管理器

私有模板仓库也可以被 `pulumi new` 使用。常见方式有三类。

第一类是 SSH：

```bash
ssh-add ~/.ssh/id_rsa
pulumi new git@github.com:myorg/private-template.git
```

如果 SSH URL 使用非标准用户，可以写成：

```bash
pulumi new myuser@git.example.com:myorg/my-template.git
```

如果 SSH key 需要 passphrase，官方文档提到可以使用环境变量：

```bash
PULUMI_GITSSH_PASSPHRASE=yourpassphrase pulumi new ssh://git@github.com/myorg/private-template.git
```

第二类是 HTTPS URL 携带凭据。它能工作，但不适合作为团队脚本或文档中的默认方式：

```bash
pulumi new https://username:token@github.com/myorg/private-template.git
```

更推荐的第三类方式是使用 Git credential helper。例如已经运行过 `gh auth login` 或配置了 Git Credential Manager 时，`pulumi new` 可以复用这些凭据：

```bash
pulumi new https://github.com/myorg/private-template.git
```

不要把 token 写进仓库、README、CI 日志或共享脚本。模板的目的在于降低项目启动成本，不应该因此扩大凭据暴露面。

## 8.7 本地测试 Template

官方文档建议用本地路径测试模板：

```bash
pulumi new ~/templates/my-aws-template
```

但测试时不要站在模板目录内部执行。因为 `pulumi new /path/to/template` 会把模板文件复制到当前目录，如果当前目录就在模板目录内，可能造成递归复制或文件冲突。

推荐流程是换到一个临时目录：

```bash
cd /tmp
mkdir template-test
cd template-test
pulumi new ~/templates/my-aws-template
pulumi preview
```

测试模板不只是确认 `pulumi new` 能跑完，还应检查生成项目能否安装依赖、能否执行 `pulumi preview`、README 命令是否准确、`secret: true` 的配置是否真的被写成机密值。

## 8.8 多模板仓库：用子目录组织不同语言和云平台

官方文档明确支持把多个模板放在同一个 Git 仓库里，并用 aws-typescript、aws-python、azure-go 这样的子目录作为示例。这说明多模板仓库可以按 cloud provider、programming language 或场景拆分模板；但官方文档并没有规定这些模板必须对应“同一种应用的多语言实现”。

从工程实践看，多模板仓库不应把彼此无关的项目随意放在一起，而更适合统一维护一组**相关模板**。一种合理用法是：同一种 Stack 或同一种应用起点，在不同云平台、不同语言里提供实现版本。例如同一个 web service 基线，可以有 aws-typescript、aws-python、azure-go 几个版本；它们共享命名、标签、README、CI 和安全约定，但使用不同 provider 或语言。

这里需要避免一个误解：**同一个团队不应该为了“看起来完整”而长期维护同一基础设施的多种语言实现**。下面这些原因不是官方文档的硬性要求，而是本教程给出的工程判断：多语言模板通常是为了服务不同使用者，而不是为了让一支团队重复写两份等价代码。例如平台团队服务的业务团队里，有的团队主要写 TypeScript，有的团队主要写 Python；给他们各自熟悉的模板，可以降低新项目启动成本。另一个常见场景是过渡期：组织准备从 Python 模板逐步切到 TypeScript 模板，短期内保留两者，让旧项目和新项目各自有稳定起点。

如果所有使用者都能接受同一种语言，通常只保留一份模板更好。这个判断来自 Template、Component 和 Package 的职责边界：Template 负责生成项目外壳和调用样例；真正需要跨语言复用的基础设施逻辑，应优先沉到 Component 或 Package 中。

一个仓库可以这样组织：

```text
templates/
├── aws-typescript/
│   ├── Pulumi.yaml
│   └── index.ts
├── aws-python/
│   ├── Pulumi.yaml
│   └── __main__.py
└── azure-go/
    ├── Pulumi.yaml
    └── main.go
```

使用者通过子目录 URL 选择具体模板：

```bash
pulumi new https://github.com/myorg/templates/tree/main/aws-typescript
```

多模板仓库适合把“同一套组织约定”放在一起管理，例如命名规则、标签键、README 模板、CI 配置、Provider 版本策略。它也可以容纳不同场景的模板，例如 service、batch job、data pipeline，但前提是这些模板确实由同一团队维护、共享同一套治理规则。

边界同样重要：不同模板之间仍要避免共享隐藏状态；每个子目录都应当可以独立被 `pulumi new` 消费。不要让一个模板依赖另一个模板目录里的相对文件，否则使用者通过子目录 URL 创建项目时很容易丢文件或得到不可运行的工程。

## 8.9 与 Pulumi Cloud Organization Templates 的边界

官方文档还提到 Organization Templates。它可以把模板发布到 Pulumi Cloud 组织的 Private Registry，并提供语义化版本、控制台集成和访问控制。这对集中治理很有价值，但属于 Pulumi Cloud 的组织能力，不在本教程 OSS 实验范围内。

在只使用 Pulumi OSS 的前提下，推荐把模板放在 Git 仓库里，通过 URL、分支和 tag 管理。这样仍然可以完成模板复用、版本固定、代码审查和本地测试。

## 8.10 Template 检查清单

写 Template 时，可以用下面这份清单自查：

| 检查项 | 建议 |
|--------|------|
| `Pulumi.yaml` | 包含 `template` 段，并使用 `${PROJECT}` 与 `${DESCRIPTION}` |
| 配置说明 | 每个配置项都有清晰的 `description` |
| 默认值 | 对常见选择提供 `default`，但允许使用者覆盖 |
| 机密值 | 对密码、token、密钥类配置使用 `secret: true` |
| README | 说明创建的资源、前置条件、常用命令和清理方式 |
| quickstart | 在 `template.quickstart` 中写清生成项目后的下一步 |
| 本地测试 | 从模板目录外运行 `pulumi new /path/to/template` |
| 版本管理 | 用 Git branch 或 tag 提供稳定模板版本 |
| 多模板仓库 | 每个子目录都能独立作为模板使用 |
| OSS 边界 | Git/local templates 可独立使用；Organization Templates 需要 Pulumi Cloud 组织能力 |

## 8.11 小结

Pulumi Template 是新项目的标准起点。它不替代 Component、Package 或 Policy Pack，而是把它们组织进一个一致的项目骨架里，让新服务从一套已审查的文件、配置提示和 README 开始。

在 OSS 范围内，最实用的模板分发方式是 Git 仓库和本地路径。只要 `Pulumi.yaml` 的 `template` 段设计清楚、配置项描述完整、机密值正确标注，并且每次改动都经过本地 `pulumi new` 测试，Template 就能成为团队基础设施工程化的第一道入口。

## 8.12 本章实验

本章实验不需要真实云账号。它会创建一个本地 Pulumi Template，用 `pulumi new` 生成项目，并验证变量替换、配置提示、Secret 配置和生成项目的 preview/up 流程。

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-templates" title="实验：Pulumi Templates" desc="创建本地 Pulumi Template，用 pulumi new 生成项目，验证 template config、secret、quickstart 与本地测试流程。" />