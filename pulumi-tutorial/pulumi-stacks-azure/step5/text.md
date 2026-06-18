# 重命名 Stack：有资源 vs 空 Stack

官方文档里有 `pulumi stack rename`。它会更新 Stack 在 State 里的名字（包括 URN 中的 stack 段），但**不会**自动改写云上的真实资源。问题在于：如果你的程序用 Stack 名生成资源的物理名，重命名后下一次 `pulumi up` 会算出一套新名字，从而计划修改这些资源。

本实验的 `__main__.py` 正是这样写的：

```python
stack = pulumi.get_stack()
resource_group_name = f"{name_prefix}-{stack}-rg"
key_vault_name = f"{name_prefix}-{stack}-kv"
```

所以 `dev` Stack 的 Resource Group 物理名是 `stack-lab-dev-rg`。一旦把 Stack 改名，`pulumi.get_stack()` 返回值变了，物理名也跟着变。

## 先看“有资源的 Stack 改名”会发生什么

我们把已经部署了资源的 `dev` 改名为 `dev2`，再用 `pulumi preview --diff` 观察 Pulumi 的计划：

```bash
cd /root/workspace/azure-stacks && \
source venv/bin/activate && \
pulumi stack select dev && \
pulumi stack rename dev2 && \
pulumi preview --diff
```{{exec}}

preview 会列出两个资源的 `~`（update）操作：Resource Group 的 `name`、`tags`，以及 Key Vault Secret 的 `vault` 都从 `stack-lab-dev-*` 变成了 `stack-lab-dev2-*`，所有 outputs 也跟着变。

这里有一个重要细节：**是 update 还是 replace，由 provider 决定。** 本实验的 `miniblue` dynamic provider 把 `name` 当成一个可以原地修改的普通属性，所以你看到的是 `~ 2 to update`。但在真实的 Azure provider 里，Resource Group / Key Vault 的 `name` 通常是不可变的（immutable），同样的改名会被标成 `replace`（`+-`）——也就是**先建新、再删旧**，可能伴随停机、数据丢失或 IP 变化。换句话说：这里模拟环境的 update 是“温和版”，生产环境里同样的改名往往是“重建版”。

因为本实验用的是 `miniblue` 模拟资源，这一步没有任何现实风险，可以放心把变更真正执行一遍，亲眼看到资源名变化：

```bash
pulumi up --yes && \
pulumi stack output resource_group && \
pulumi stack output key_vault
```{{exec}}

输出已经变成 `stack-lab-dev2-rg` 和 `stack-lab-dev2-kv`。在这个模拟 provider 里资源是被原地更新的；换成真实 Azure，同一步则会是“先建 `stack-lab-dev2-*`、再删 `stack-lab-dev-*`”的重建。**记住这个教训：生产环境里，重命名“资源名依赖 Stack 名”的 Stack 前，一定先 `pulumi preview --diff` 看清楚是 update 还是 replace。**

## 再看“空 Stack 改名”有多安全

对照之下，没有任何资源的 Stack 改名是纯元数据操作，不会触发任何替换。先创建一个临时空 Stack，再改名：

```bash
{ pulumi stack init review-123 || pulumi stack select review-123; } && \
pulumi stack rename review-east && \
pulumi stack ls
```{{exec}}

这个 Stack 没有资源，所以可以直接删除 Stack 记录：

```bash
pulumi stack select dev2 && \
pulumi stack rm --yes review-east && \
pulumi stack ls
```{{exec}}

最后清理 `dev2` 和 `prod` 创建的模拟 Azure 资源，并关闭 `miniblue`：

```bash
pulumi stack select dev2 && pulumi destroy --yes && \
pulumi stack select prod && pulumi destroy --yes && \
cd /root/workspace && \
docker compose down
```{{exec}}

记住顺序：先 `pulumi destroy` 销毁资源，再用 `pulumi stack rm` 删除没有资源的 Stack 记录。`stack rm` 不是销毁云资源的替代品。