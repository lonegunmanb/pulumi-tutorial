# 创建 dev Stack 与 Secret

这一步我们要做两件事：创建一个用于开发的 `dev` Stack，并为它设置普通配置（如名称前缀）和机密（例如管理员密码）。把 Stack 想象成“同一份基础代码的一个命名环境”，它有自己的配置和状态，不会与其他 Stack 干扰。

先创建或切换到 `dev` Stack，并写入配置：

```bash
cd /root/workspace/azure-infra && \
{ pulumi stack init dev || pulumi stack select dev; } && \
pulumi config set namePrefix pulumi-stack-lab && \
pulumi config set owner dev-team && \
pulumi config set --secret adminPassword dev-password-123 && \
pulumi config && \
cat Pulumi.dev.yaml
```{{exec}}

命令说明：
- `{ pulumi stack init dev || pulumi stack select dev; }`：如果 `dev` 不存在就创建它，否则切换到 `dev`。
- `pulumi config set`：设置普通（明文）配置项，例如 `namePrefix` 与 `owner`。
- `pulumi config set --secret`：设置加密配置项（Secret），Pulumi 会把它以加密形式存储到 Stack 配置中。
- `pulumi config` 与 `cat Pulumi.dev.yaml`：用来确认你写入的配置已经生效。

现在部署 `dev` Stack，并查看输出：

```bash
pulumi preview && \
pulumi up --yes && \
pulumi stack output && \
pulumi stack output adminPasswordPreview --show-secrets
```{{exec}}

说明要点：
- `pulumi preview`：显示 Pulumi 将要对云资源做的更改（不会执行）。
- `pulumi up --yes`：应用变更，创建或更新资源。
- `pulumi stack output`：显示此 Stack 导出的值（例如创建的资源名称）。
-对于标记为 `secret` 的输出或配置，Pulumi 默认不会在终端明文展示；要查看明文需要显式使用 `--show-secrets`。

补充：`Pulumi.dev.yaml` 中的键名会包含 Project 前缀，例如 `projects-stacks-azure-infra:namePrefix`，这是 Pulumi 为避免不同 Project 间配置冲突所做的命名约定。