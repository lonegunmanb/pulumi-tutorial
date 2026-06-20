# 创建第一个 Stash

实验项目已经准备在 /root/workspace。先查看当前程序：

```bash
cd /root/workspace && \
cat index.ts
```{{exec}}

这段程序创建一个 Stash 资源。它读取 releaseLabel 配置作为当前输入，并导出当前输入与保存值两个 Stack Output。

先确认当前配置：

```bash
cd /root/workspace && \
pulumi config
```{{exec}}

执行第一次部署：

```bash
cd /root/workspace && \
pulumi up --yes --non-interactive && \
pulumi stack output
```{{exec}}

第一次创建时，当前输入和保存值相同。此时 Stash 已经把这个值写入当前 Stack 的 state。