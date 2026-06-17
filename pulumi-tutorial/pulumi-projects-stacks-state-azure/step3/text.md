# 复制配置创建 prod Stack

上一节我们已经部署了一个 `dev` Stack。这里先把 **Stack** 理解成“同一个 Pulumi Project 的一套独立环境”：它复用同一份代码，但拥有自己的配置、状态文件和输出结果。常见做法是用 `dev` 表示开发环境，用 `prod` 表示生产环境。

现在我们要创建 `prod` Stack。为了避免从零重复输入配置，先从 `dev` 复制一份配置，再把属于生产环境的差异覆盖掉，例如负责人和管理员密码：

```bash
cd /root/workspace/azure-infra && \
{ pulumi stack init prod --copy-config-from dev || pulumi stack select prod; } && \
pulumi config set owner prod-team && \
pulumi config set --secret adminPassword prod-password-456 && \
pulumi stack ls && \
pulumi config && \
cat Pulumi.prod.yaml
```{{exec}}

这段命令会依次完成几件事：如果 `prod` Stack 还不存在，就用 `dev` 的配置创建它；如果已经存在，就直接切换到 `prod`。随后我们覆盖 `owner` 和加密的 `adminPassword`，再用 `pulumi stack ls`、`pulumi config` 和 `cat Pulumi.prod.yaml` 确认当前 Stack 以及它的配置内容。

接下来部署 `prod`。注意我们没有改 Python 代码，只是换了 Stack。Pulumi 会根据 `prod` 的配置和状态，创建另一组命名不同的模拟 Azure 资源：

```bash
pulumi preview && \
pulumi up --yes && \
pulumi stack output resource_group && \
pulumi stack output key_vault && \
pulumi stack output handoff_card
```{{exec}}

部署前的 `pulumi preview` 会先展示计划变更；`pulumi up --yes` 才真正执行；最后几个 `pulumi stack output` 用来读取这个 Stack 暴露给外部使用的资源名称和交接信息。

回头看这一节的核心：`dev` 与 `prod` 的代码完全相同，差异来自 Stack 名称、Stack Config，以及各自独立保存的 State。这就是 Pulumi 用 Stack 管理多环境的基本方式。