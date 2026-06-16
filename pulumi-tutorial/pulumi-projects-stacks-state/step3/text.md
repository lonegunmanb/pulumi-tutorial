# 复制配置创建 prod Stack

用 `--copy-config-from dev` 复制 `dev` 的配置，创建 `prod` Stack，再覆盖环境差异：

```bash
cd /root/workspace/aws-infra && \
{ pulumi stack init prod --copy-config-from dev || pulumi stack select prod; } && \
pulumi config set owner prod-team && \
pulumi config set --secret serviceToken prod-token-456 && \
pulumi stack ls && \
pulumi config && \
cat Pulumi.prod.yaml
```{{exec}}

部署 `prod`，同一份 Project 代码会因为当前 Stack 不同而创建另一个 Bucket：

```bash
pulumi preview && \
pulumi up --yes && \
pulumi stack output bucketName && \
pulumi stack output handoffCard
```{{exec}}

`dev` 与 `prod` 的代码完全相同，差异来自 Stack 名称和 Stack Config。