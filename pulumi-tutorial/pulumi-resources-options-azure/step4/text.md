# aliases 零重建迁移

重命名一个资源的 **logical name** 默认会被 Pulumi 当成「删除旧资源 + 新建资源」，因为 URN 变了。`aliases` 的作用就是告诉 Pulumi「新名字其实就是旧资源」，从而**零重建**。

**1) 先看不加 alias 的代价**：

先看这一步要运行的代码：

```bash
cat /root/workspace/variants/step4-noalias.ts
```{{exec}}

再预览：

```bash
cd /root/workspace && cp variants/step4-noalias.ts index.ts && pulumi preview
```{{exec}}

`step4-noalias.ts` 把 `media-rg` 改名成 `assets-rg`，没有加 alias。预览会显示 `+ assets-rg`（create）和 `- media-rg`（delete）——这是一次彻底的重建，物理资源会被销毁。

**2) 加上 `aliases` 认领旧资源**：

先看改动后的代码：

```bash
cat /root/workspace/variants/step4.ts
```{{exec}}

再预览：

```bash
cp variants/step4.ts index.ts && pulumi preview
```{{exec}}

`step4.ts` 在 `assets-rg` 上加了 `aliases: [{ name: "media-rg" }]`。这次预览里**没有 create/delete**，最多是一次 metadata 层面的 update——物理 Resource Group 原地保留。

应用它：

```bash
pulumi up --yes && \
pulumi stack export | jq '.deployment.resources[] | select(.type=="azure:core/resourceGroup:ResourceGroup") | .urn'
```{{exec}}

URN 已变为 `...::assets-rg`，但底层物理资源从未被销毁。

要点：

- 改 logical name = 改 URN = 默认重建。重构资源树（改名、移进/移出 Component）时务必配 `aliases`。
- `aliases` 是**迁移期**的桥梁，但删它要谨慎：alias 是在某个 stack `pulumi up` 时才把 state 里的旧 URN 迁移成新名字的，而这个迁移是**每个 stack 各自发生**的。只有当**所有**会用到该资源的 stack 都已经跑过一次带 alias 的 `up`、state 全部迁移完毕后，才能安全移除。
- 尤其是被其他人复用的公共 **component**：若某个消费者 stack 还没升级到带 alias 的版本就直接用上了「无 alias」的新版，它下次 `up` 会看到「旧 URN 还在 state、代码里是新名字、却没有 alias」，从而退回删旧建新的重建。因此公共 component 的 alias 往往要保留一个很长的弃用周期，甚至长期保留。
