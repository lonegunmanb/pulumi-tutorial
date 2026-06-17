# 创建 dev/prod Stack 与配置

现在创建第一个 Stack：`dev`。Stack 是当前 Project 的一个独立环境，`pulumi config set` 写入的是当前 active stack 的配置。

```bash
cd /root/workspace/azure-stacks && \
export PULUMI_CONFIG_PASSPHRASE="" && \
source venv/bin/activate && \
{ pulumi stack init dev || pulumi stack select dev; } && \
pulumi config set namePrefix stack-lab && \
pulumi config set owner dev-team && \
pulumi config set tier development && \
pulumi config set --secret adminPassword dev-pass-123 && \
pulumi stack ls && \
pulumi config && \
cat Pulumi.dev.yaml
```{{exec}}

注意 `pulumi stack ls` 输出里的 `*`：它表示当前 active stack。后续 `preview`、`up`、`destroy` 都会作用在这个 Stack 上。

接着创建 `prod` Stack。这里从 `dev` 复制配置，再覆盖生产环境自己的差异。

```bash
{ pulumi stack init prod --copy-config-from dev || pulumi stack select prod; } && \
pulumi config set owner prod-team && \
pulumi config set tier production && \
pulumi config set --secret adminPassword prod-pass-456 && \
pulumi stack ls && \
pulumi config && \
cat Pulumi.prod.yaml
```{{exec}}

你现在有两个 Stack：

- `dev`：开发环境配置。
- `prod`：生产环境配置。

它们共享同一份 `__main__.py`，但配置文件、Secret、后续 State 都彼此独立。

这里显式设置 `PULUMI_CONFIG_PASSPHRASE=""`，是为了让当前终端也使用本实验约定的本地后端空口令。后续命令在同一个终端里继续执行即可。