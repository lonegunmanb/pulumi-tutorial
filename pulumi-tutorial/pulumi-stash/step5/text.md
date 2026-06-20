# 删除 Stash

最后观察删除行为。把程序切换成一个不再声明 Stash 资源的版本：

```bash
cd /root/workspace && \
cp variants/empty.ts index.ts && \
cat index.ts
```{{exec}}

运行部署，Pulumi 会把之前声明的 Stash 从 state 中移除：

```bash
cd /root/workspace && \
pulumi up --yes --non-interactive && \
pulumi stack output
```{{exec}}

再查看 state 中的资源类型，确认不再包含 Stash：

```bash
cd /root/workspace && \
pulumi stack export | jq -r '.deployment.resources[].type'
```{{exec}}

删除后，原先保存的值不再属于当前 Stack。以后如果重新添加同名 Stash，它会作为一次新的创建重新保存当时的输入。