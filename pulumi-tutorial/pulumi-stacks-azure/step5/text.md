# 重命名空 Stack 与清理

官方文档里有 `pulumi stack rename`，但要特别小心：如果你的程序用 Stack 名生成资源名，重命名已有资源的 Stack 可能导致下一次 `pulumi up` 计划替换资源。

所以这里只演示“空 Stack”的安全重命名流程。先创建一个临时 Stack，再把它改名：

```bash
cd /root/workspace/azure-stacks && \
source venv/bin/activate && \
{ pulumi stack init review-123 || pulumi stack select review-123; } && \
pulumi stack rename review-east && \
pulumi stack ls
```{{exec}}

这个 Stack 没有资源，所以可以直接删除 Stack 记录：

```bash
pulumi stack select dev && \
pulumi stack rm --yes review-east && \
pulumi stack ls
```{{exec}}

最后清理 `dev` 和 `prod` 创建的模拟 Azure 资源，并关闭 `miniblue`：

```bash
pulumi stack select dev && pulumi destroy --yes && \
pulumi stack select prod && pulumi destroy --yes && \
cd /root/workspace && \
docker compose down
```{{exec}}

记住顺序：先 `pulumi destroy` 销毁资源，再用 `pulumi stack rm` 删除没有资源的 Stack 记录。`stack rm` 不是销毁云资源的替代品。