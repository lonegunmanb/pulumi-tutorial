# 用安装脚本安装 Pulumi CLI

先确认当前环境里还没有 Pulumi：

```bash
command -v pulumi || echo "Pulumi 尚未安装"
```{{exec}}

用官方安装脚本安装 Pulumi CLI。脚本会下载与架构匹配的二进制，并解压到 `~/.pulumi/bin`：

```bash
curl -fsSL https://get.pulumi.com | sh
```{{exec}}

看到 `Pulumi has been installed!` 的提示即表示二进制已就位。注意此时新的 `pulumi` 命令还不在当前 shell 的 `PATH` 中，下一步来配置它。