# 平台 Stack：共享数据库基线

先进入平台 Project。它只负责创建共享的 PostgreSQL 参数组，并把参数组名作为 Output 暴露给下游。

```bash
source /root/.pulumi-best-practices-aws-env.sh && \
cd /root/workspace/best-practices-aws/platform && \
sed -n '1,180p' index.ts
```{{exec}}

创建 `dev` Stack 并部署平台基线：

```bash
source /root/.pulumi-best-practices-aws-env.sh && \
cd /root/workspace/best-practices-aws/platform && \
{ pulumi stack init dev || pulumi stack select dev; } && \
pulumi up --yes
```{{exec}}

查看平台交接给工作负载的输出：

```bash
pulumi stack output parameterGroupName && \
pulumi stack output platformContract
```{{exec}}

这个 Stack 是共享基础设施边界。后面的 orders 和 billing 数据库都会读取它的输出，但不会接管这个参数组。