# 定位缺失 Stack 配置

先查看当前 Pulumi 程序。它只读取两个必填配置，不加载 Azure provider。

```bash
source /root/.pulumi-debugging-azure-env.sh && \
cd /root/workspace/debugging-azure && \
sed -n '1,180p' index.ts && \
pulumi stack select dev
```{{exec}}

这个程序用 `Config.require` 读取 owner 和 environment。Pulumi 会在程序执行时检查它们；如果缺失，preview 或 up 会被阻止。本实验环境里这个运行时错误可能只显示为较笼统的进程退出码，所以这里先用 Pulumi CLI 读取同一组配置键，让 pulumi 命令自己报错。

```bash
source /root/.pulumi-debugging-azure-env.sh && \
cd /root/workspace/debugging-azure && \
pulumi config && \
(pulumi config get owner || true) && \
(pulumi config get environment || true)
```{{exec}}

这里的重点不是 Resource Group，也不是 miniblue，而是先确认 Stack 配置是否满足程序的必填项。上面的失败来自 pulumi 命令本身；命令块里的 true 分支只是为了让 Killercoda 继续执行后续步骤。下一步补齐配置后，preview 仍会运行 Pulumi 程序并执行同样的必填校验。