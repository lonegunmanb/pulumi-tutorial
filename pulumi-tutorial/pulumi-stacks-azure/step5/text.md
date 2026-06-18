# 重命名 Stack：有资源 vs 空 Stack

官方文档里有 `pulumi stack rename`。它会更新 Stack 在 State 里的名字（包括 URN 中的 stack 段），但**不会**自动改写云上的真实资源。问题在于：如果你的程序用 Stack 名生成资源的物理名，重命名后下一次 `pulumi up` 会算出一套新名字，从而计划**替换**资源。

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

注意 diff 里出现的 `replace`（或 `+-`）操作：因为 Resource Group 与 Key Vault 的物理名从 `stack-lab-dev-*` 变成了 `stack-lab-dev2-*`，名字变更属于不可原地修改的属性，Pulumi 只能**先建新、再删旧**。在真实云上，这意味着资源真的会被重建——可能伴随停机、数据丢失或 IP 变化。

因为本实验用的是 `miniblue` 模拟资源，替换没有任何现实风险，所以这里可以放心地把替换真正执行一遍，亲眼看到资源名变化：

```bash
pulumi up --yes && \
pulumi stack output resource_group && \
pulumi stack output key_vault
```{{exec}}

输出已经变成 `stack-lab-dev2-rg` 和 `stack-lab-dev2-kv`，旧的 `stack-lab-dev-*` 资源在这一步被销毁了。**记住这个教训：生产环境里，重命名“资源名依赖 Stack 名”的 Stack 前，一定先 `pulumi preview` 确认是否会触发替换。**

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