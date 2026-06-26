# 工作负载 Stack：组件化数据库

现在进入工作负载 Project。它通过 StackReference 读取平台输出，再把数据库创建封装在组件里。

```bash
source /root/.pulumi-best-practices-aws-env.sh && \
cd /root/workspace/best-practices-aws/workload && \
sed -n '1,220p' src/secure-postgres.ts && \
sed -n '1,160p' index.ts
```{{exec}}

为 `orders-dev` 写入配置。密码使用 Secret 保存，程序会用 requireSecret 读取。

```bash
source /root/.pulumi-best-practices-aws-env.sh && \
cd /root/workspace/best-practices-aws/workload && \
{ pulumi stack init orders-dev || pulumi stack select orders-dev; } && \
pulumi config set service orders && \
pulumi config set environment dev && \
pulumi config set size dev && \
pulumi config set platformStack dev && \
pulumi config set --secret dbPassword 'Correct-Horse-1'
```{{exec}}

部署数据库。MiniStack RDS 会在本地模拟控制面，并为实例分配 PostgreSQL endpoint。

```bash
pulumi up --yes && \
pulumi stack output dbIdentifier && \
pulumi stack output dbEndpoint
```{{exec}}

观察 state 里的父子关系。RDS 实例挂在组件下面，组件本身又挂在 Stack 下面。

```bash
pulumi stack export | jq -r '.deployment.resources[] | [.type, (.urn | split("::") | last), (.parent // "-" | split("::") | last)] | @tsv'
```{{exec}}