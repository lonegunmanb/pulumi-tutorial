# 创建 dev Stack 与 Secret

现在开始创建第一个 Stack：`dev`。如果把 Project 理解成一套“基础设施模板”，那 Stack 就是这套模板的一个具体环境，比如开发环境、测试环境或生产环境。

这一步会创建 `dev` Stack，并为它设置普通配置和机密配置：

```bash
cd /root/workspace/aws-infra && \
{ pulumi stack init dev || pulumi stack select dev; } && \
pulumi config set bucketBase pulumi-stack-lab && \
pulumi config set owner dev-team && \
pulumi config set --secret serviceToken dev-token-123 && \
pulumi config && \
cat Pulumi.dev.yaml
```{{exec}}

这段命令做了几件事：
- 如果 `dev` Stack 不存在，就创建它；如果已经存在，就切换过去。
- `bucketBase` 和 `owner` 是普通配置，会以明文形式保存在 Stack 配置里。
- `serviceToken` 使用 `--secret` 设置，表示它会被 Pulumi 以加密形式保存。
- 最后的 `pulumi config` 和 `cat Pulumi.dev.yaml` 用来确认当前 Stack 的配置内容。

接下来部署 `dev` Stack，并读取输出：

```bash
pulumi preview && \
pulumi up --yes && \
pulumi stack output && \
pulumi stack output serviceTokenPreview --show-secrets
```{{exec}}

观察 `pulumi config` 和 `pulumi stack output`：Secret 默认显示为 `[secret]`，只有显式使用 `--show-secrets` 才会显示明文。

再看 `Pulumi.dev.yaml`：你设置的 `bucketBase` 会以 `projects-stacks-aws-infra:bucketBase` 的形式存储。前缀来自 `Pulumi.yaml` 里的 Project 名，用来避免不同 Project 或 Provider 的配置键冲突。

这一步最重要的理解是：**同一份代码，配上不同的 Stack 和不同的配置，就能代表不同环境。**