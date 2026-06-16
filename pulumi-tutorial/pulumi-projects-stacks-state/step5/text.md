# 用 StackReference 跨项目读取输出

进入下游 Project。它不会创建 AWS 资源，只读取上游 `aws-infra` 对应 Stack 的 Outputs。

关键点：`StackReference` 里的 `projects-stacks-aws-infra` 必须与上游 `Pulumi.yaml` 的 `name` 字段完全一致；本地后端的组织名前缀固定写作 `organization`。

```bash
cd /root/workspace/aws-consumer && \
cat Pulumi.yaml && \
sed -n '1,120p' index.ts
```{{exec}}

创建并部署 `dev` Stack。它会读取 `organization/projects-stacks-aws-infra/dev`：

```bash
{ pulumi stack init dev || pulumi stack select dev; } && \
pulumi up --yes && \
pulumi stack output sourceBucket && \
pulumi stack output sourceHandoffCard
```{{exec}}

再创建并部署 `prod` Stack。因为当前 Stack 变成 `prod`，`StackReference` 会读取上游的 `prod` 输出：

```bash
{ pulumi stack init prod || pulumi stack select prod; } && \
pulumi up --yes && \
pulumi stack output sourceBucket && \
pulumi stack output sourceHandoffCard && \
pulumi stack output referencedSecret --show-secrets
```{{exec}}

最后清理两个 Project 的资源和 MiniStack：

```bash
cd /root/workspace/aws-consumer && \
pulumi stack select dev && pulumi destroy --yes && \
pulumi stack select prod && pulumi destroy --yes && \
cd /root/workspace/aws-infra && \
pulumi stack select dev && pulumi destroy --yes && \
pulumi stack select prod && pulumi destroy --yes && \
cd /root/workspace && \
docker compose down
```{{exec}}