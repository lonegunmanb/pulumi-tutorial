# 定位缺失 Stack 配置

先查看当前 Pulumi 程序。它只读取两个必填配置，不加载 Azure provider。

```bash
source /root/.pulumi-debugging-azure-env.sh && \
cd /root/workspace/debugging-azure && \
sed -n '1,180p' index.ts && \
pulumi stack select dev
```{{exec}}

这个程序用 `Config.require` 读取 owner 和 environment。当前 Stack 暂时没有配置，所以 preview 会在调用 miniblue 之前失败。

```bash
source /root/.pulumi-debugging-azure-env.sh && \
cd /root/workspace/debugging-azure && \
pulumi config && \
pulumi preview --diff || true
```{{exec}}

观察 Diagnostics。这里的重点不是 Resource Group，也不是 miniblue，而是 Pulumi 程序在语言运行阶段就发现了缺失配置。下一步会切换到真实资源程序。