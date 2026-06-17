# 复制配置创建 prod Stack

上一节你已经有了一个 `dev` Stack。现在我们要创建 `prod` Stack，也就是同一份 Project 的另一套独立环境。

这里有个很实用的做法：直接复制 `dev` 的配置，再把生产环境和开发环境不同的部分覆盖掉。这样既省时间，也能减少漏配项。

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

这段命令的含义是：
- 如果 `prod` 不存在，就按 `dev` 的配置复制出一个新 Stack。
- 如果 `prod` 已经存在，就直接切换到它。
- 然后把 `owner` 和 `serviceToken` 改成属于生产环境的值。

接下来部署 `prod`。虽然代码完全没变，但因为当前 Stack 不同、配置不同，所以 Pulumi 会创建另一套独立资源：

```bash
pulumi preview && \
pulumi up --yes && \
pulumi stack output bucketName && \
pulumi stack output handoffCard
```{{exec}}

这里最值得记住的一点是：`dev` 与 `prod` 的代码完全相同，差异来自 **Stack 名称** 和 **Stack Config**。Pulumi 就是靠这两者来管理多环境的。