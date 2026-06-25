# 定位缺失 Stack 配置

先查看当前 Pulumi 程序。它会读取两个必填配置，然后声明一个本地 S3 Bucket。

```bash
source /root/.pulumi-debugging-aws-env.sh && \
cd /root/workspace/debugging-aws && \
sed -n '1,180p' index.ts && \
pulumi stack select dev
```{{exec}}

这个程序用 `Config.require` 读取 owner 和 environment。当前 Stack 暂时没有配置，所以 preview 会在调用 MiniStack 之前失败。

```bash
source /root/.pulumi-debugging-aws-env.sh && \
cd /root/workspace/debugging-aws && \
pulumi config && \
pulumi preview --diff || true
```{{exec}}

观察 Diagnostics。这里的重点不是 S3，也不是 MiniStack，而是 Pulumi 程序在语言运行阶段就发现了缺失配置。