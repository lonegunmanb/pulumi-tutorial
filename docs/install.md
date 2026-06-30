---
order: 15
title: 如何安装 Pulumi
group: 第 1 篇：Get Started & 架构基石
---

# 如何安装 Pulumi

<TutorialAcknowledgement />

> 官方参照：[Get started with Pulumi and AWS / Install Pulumi](https://www.pulumi.com/docs/iac/get-started/aws/begin/) 与 [Download & Install Pulumi](https://www.pulumi.com/docs/install/)。本章沿用 AWS 起步教程的节奏：先安装 Pulumi CLI，再用 `pulumi version` 验证；动手实验只演示 Linux 版本，并固定使用本地后端。

## 本章定位

在写第一行基础设施代码之前，你需要把一套可用的 Pulumi 工作台准备好，它由三部分组成：

- **Pulumi CLI**：命令行入口与部署引擎，负责执行 `preview`、`up`、`destroy` 等核心工作流。
- **语言运行时**：例如 Node.js / Python / Go，用来运行你的 IaC 程序。本教程使用 TypeScript，所以需要 Node.js。
- **状态后端（State Backend）**：保存资源快照。官方默认后端是 Pulumi Cloud；本教程固定使用本地文件后端。

一句话记住安装的本质：**安装 Pulumi CLI 不需要任何账号**。本教程不会要求你登录 Pulumi 官方服务；后续统一使用 `pulumi login --local`，状态保存在本机。

## 官方映射

- 主参照：[Get started with Pulumi and AWS / Install Pulumi](https://www.pulumi.com/docs/iac/get-started/aws/begin/)：对应本章 0.2 到 0.5 的安装与 `pulumi version` 验证流程。
- 通用安装页：[Download & Install Pulumi](https://www.pulumi.com/docs/install/)（源码路径 `content/docs/install/`）。
- 延伸文档：
  - [State and Backends](https://www.pulumi.com/docs/iac/concepts/state-and-backends/)：对应 `pulumi login --local` 的本地后端取舍。
  - [AWS Configure access](https://www.pulumi.com/docs/iac/get-started/aws/configure/)：这是官方 AWS 起步教程的下一步；本章不进入 AWS 凭据配置。

## 0.1 安装前需要知道的三件事

1. **CLI 与账号是解耦的。** 你可以先把 CLI 装好、用 `pulumi version` 验证，然后再决定用哪个后端。装 CLI 这一步永远不需要登录。
2. **安装位置因方法而异。** 用官方安装脚本时，CLI 会被装到家目录下的 `~/.pulumi/bin`，因此你必须把这个目录加入 `PATH`；用 Homebrew / winget / Chocolatey 等包管理器时，PATH 通常会被自动处理。
3. **离线环境可关闭版本检查。** CLI 每次运行都会检查新版本，在没有外网的环境里把环境变量 `PULUMI_SKIP_UPDATE_CHECK` 设为 `1` 即可跳过。

## 0.2 在 Linux 上安装（本教程动手实验所用）

Linux 上最通用、最少依赖的方式是官方安装脚本。它会下载与你的架构匹配的二进制并解压到 `~/.pulumi/bin`：

```bash
curl -fsSL https://get.pulumi.com | sh
```

脚本默认不会修改你的 shell 配置，所以安装完成后需要把 `~/.pulumi/bin` 加入 `PATH`。对 Bash 用户：

```bash
export PATH="$PATH:$HOME/.pulumi/bin"
echo 'export PATH="$PATH:$HOME/.pulumi/bin"' >> ~/.bashrc
source ~/.bashrc
```

> 如果你用 zsh，请把上面的 `~/.bashrc` 换成 `~/.zshrc`。

**安装指定版本。** 生产环境通常要锁定版本，避免团队成员之间出现版本漂移：

```bash
curl -fsSL https://get.pulumi.com | sh -s -- --version 3.246.0
```

**手动安装（无 `curl | sh` 策略时）。** 一些受控环境不允许把远程脚本直接管道给 shell，可以改为下载压缩包后自行解压：

```bash
curl -fsSL https://get.pulumi.com/releases/sdk/pulumi-v3.246.0-linux-x64.tar.gz -o pulumi.tar.gz
tar -xzf pulumi.tar.gz
sudo mv pulumi/* /usr/local/bin/
```

**使用 Homebrew on Linux。** 如果你已经在 Linux 上装了 Homebrew，也可以用它来安装并自动管理 PATH：

```bash
brew install pulumi/tap/pulumi
```

## 0.3 在 macOS 上安装

推荐使用 Homebrew，它会自动处理 PATH 与后续升级：

```bash
brew install pulumi/tap/pulumi
```

也可以使用与 Linux 相同的安装脚本（安装到 `~/.pulumi/bin`，同样需要配置 PATH）：

```bash
curl -fsSL https://get.pulumi.com | sh
```

## 0.4 在 Windows 上安装

任选一种包管理器，PATH 会被自动配置：

```powershell
# Windows Package Manager (winget)
winget install Pulumi.Pulumi

# 或 Chocolatey
choco install pulumi
```

也可以从官方下载 **MSI 安装包** 双击安装，或在命令提示符 / PowerShell 中运行安装脚本：

```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://get.pulumi.com/install.ps1'))
```

脚本方式会把 CLI 装到 `%USERPROFILE%\.pulumi\bin`，必要时把它加入 `PATH` 后重开终端。

## 0.5 验证安装

无论用哪种方式，安装完成后都用同一条命令确认：

```bash
pulumi version
```

如果终端打印出形如 `v3.246.0` 的版本号，说明 CLI 已经在 `PATH` 中、可以正常工作。官方 AWS 起步教程也以这一步作为安装验证；如果命令不可用，先重开终端，再检查 PATH。

## 0.6 选择状态后端

CLI 装好后，第一次执行真正的工作流前需要选一个后端来保存状态。为避免任何官方账号依赖，本教程只使用本地后端：

```bash
# 使用本地文件后端，状态保存在 ~/.pulumi 下，零账号
pulumi login --local

# 确认当前后端
pulumi whoami --verbose
```

> 不要运行不带参数的 `pulumi login`：它会进入 Pulumi Cloud 登录流程。本教程的目标是把状态、实验与清理都留在本地，确保学习过程不依赖 Pulumi 官方账号。

## 0.7 安装语言运行时

Pulumi 用真实编程语言描述基础设施，所以还需要对应的语言运行时。本教程使用 TypeScript，需要 **Node.js 18 及以上**：

```bash
node --version
npm --version
```

如果尚未安装，可参照 [Node.js 官方下载](https://nodejs.org/)。Python、Go、.NET、Java 用户请安装各自的运行时；CLI 与后端的用法完全一致。

## 0.8 升级、指定版本与卸载

| 操作 | 命令 |
|------|------|
| 升级（脚本/手动安装） | 重新运行 `curl -fsSL https://get.pulumi.com \| sh` |
| 升级（Homebrew） | `brew upgrade pulumi` |
| 安装指定版本 | `curl -fsSL https://get.pulumi.com \| sh -s -- --version <版本号>` |
| 卸载（Homebrew） | `brew uninstall pulumi` |
| 卸载（脚本安装） | 删除二进制并移除 `~/.pulumi` 目录 |

> 卸载后建议一并删除家目录下的 `.pulumi` 文件夹，它缓存了插件与元数据。

## 0.9 常见问题排查

- **`pulumi: command not found`**：几乎都是 PATH 没配好。确认 `~/.pulumi/bin`（脚本安装）确实在 `$PATH` 中，并重开一个终端。
- **每次命令都提示有新版本**：这是正常的版本检查。离线或 CI 环境可设 `export PULUMI_SKIP_UPDATE_CHECK=1` 关闭。
- **下载缓慢或被防火墙拦截**：改用 0.2 的「手动安装」方式，或在内网镜像中预置二进制。

## 最小系统要求

| 资源 | 建议下限 |
|------|----------|
| CPU | 2 GHz 或更快（云上等价 vCPU） |
| 内存 | 4 GB 及以上 |
| 磁盘 | 1 GB 以上可用空间（多运行时 / 大型 Provider 需更多） |

## 动手实验

下面的 Killercoda 场景在一台干净的 Linux 终端里，带你用官方脚本从零安装 Pulumi CLI、配置 PATH、验证版本，并选择本地后端。

<KillercodaEmbed src="https://killercoda.com/pulumi-tutorial/course/pulumi-tutorial/pulumi-get-started" title="实验：在 Linux 上安装 Pulumi" desc="用 get.pulumi.com 安装脚本安装 Pulumi CLI，配置 PATH，运行 pulumi version 验证，并用 pulumi login --local 选择本地后端，无需 Pulumi 官方账号。" />

## 本章交付物

- 三大操作系统的 Pulumi CLI 安装方法速查。
- `PATH` 配置与 `pulumi version` 验证清单。
- 本地后端选择与无需官方登录的验证清单。
- 升级 / 指定版本 / 卸载与常见问题排查手册。

