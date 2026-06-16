# 创建 dev Stack 与 Secret

创建 `dev` Stack，并为它设置明文 Config 与加密 Secret：

```bash
cd /root/workspace/azure-infra && \
{ pulumi stack init dev || pulumi stack select dev; } && \
pulumi config set namePrefix pulumi-stack-lab && \
pulumi config set owner dev-team && \
pulumi config set --secret adminPassword dev-password-123 && \
pulumi config && \
cat Pulumi.dev.yaml
```{{exec}}

部署 `dev` Stack，并读取输出：

```bash
pulumi preview && \
pulumi up --yes && \
pulumi stack output && \
pulumi stack output adminPasswordPreview --show-secrets
```{{exec}}

观察 `adminPasswordPreview`：默认输出会被标记为 `[secret]`，只有显式使用 `--show-secrets` 才显示明文。

再看 `Pulumi.dev.yaml`：你设置的 `namePrefix` 会以 `projects-stacks-azure-infra:namePrefix` 的形式存储。前缀来自 `Pulumi.yaml` 里的 Project 名，用来避免不同 Project 或 Provider 的配置键冲突。