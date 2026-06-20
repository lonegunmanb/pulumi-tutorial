# 替换 Stash，刷新保存值

如果确实要让保存值更新，需要替换这个 Stash 资源。先从 state 中找出它的 URN：

```bash
cd /root/workspace && \
pulumi stack export | jq -r '.deployment.resources[] | select(.type == "pulumi:index:Stash" and (.urn | endswith("::release-label"))) | .urn'
```{{exec}}

现在把这个 URN 传给定向替换参数。Pulumi 会删除旧 Stash，再用当前输入创建新的 Stash。

```bash
cd /root/workspace && \
STASH_URN="$(pulumi stack export | jq -r '.deployment.resources[] | select(.type == "pulumi:index:Stash" and (.urn | endswith("::release-label"))) | .urn')" && \
printf '%s\n' "$STASH_URN" && \
pulumi up --yes --non-interactive --target-replace "$STASH_URN" && \
pulumi stack output
```{{exec}}

替换完成后，保存值也变成了新的版本标签。以后再次修改当前输入时，保存值会继续保持这次替换时记录的内容。