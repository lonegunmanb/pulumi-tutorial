# 更新 input，观察 output 保持不变

现在只修改配置，让程序下一次传给 Stash 的当前输入变成新的版本标签。

```bash
cd /root/workspace && \
pulumi config set releaseLabel release-002 && \
pulumi preview --diff --non-interactive
```{{exec}}

预览会显示 Stash 的输入发生了变化。注意这只是当前输入变化，还不是保存值变化。

应用这次更新并查看输出：

```bash
cd /root/workspace && \
pulumi up --yes --non-interactive && \
pulumi stack output
```{{exec}}

你会看到当前输入已经是新的版本标签，但保存值仍然是第一次创建时的标签。这正是 Stash 的核心行为。