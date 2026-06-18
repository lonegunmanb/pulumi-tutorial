# aliases 零重建迁移

重命名一个资源的 **logical name** 默认会被 Pulumi 当成「删除旧资源 + 新建资源」，因为 URN 变了。`aliases` 的作用就是告诉 Pulumi「新名字其实就是旧资源」，从而**零重建**。

**1) 先看不加 alias 的代价**：

```bash
cd /root/workspace && cp variants/step4-noalias.ts index.ts && pulumi preview
```{{exec}}

`step4-noalias.ts` 把 `media-bucket` 改名成 `assets-bucket`，没有加 alias。预览会显示 `+ assets-bucket`（create）和 `- media-bucket`（delete）——这是一次彻底的重建，物理资源会被销毁。

**2) 加上 `aliases` 认领旧资源**：

```bash
cp variants/step4.ts index.ts && pulumi preview
```{{exec}}

`step4.ts` 在 `assets-bucket` 上加了 `aliases: [{ name: "media-bucket" }]`。这次预览里**没有 create/delete**，最多是一次 metadata 层面的 update——物理 Bucket 原地保留。

应用它：

```bash
pulumi up --yes && \
pulumi stack export | jq '.deployment.resources[] | select(.type=="aws:s3/bucket:Bucket") | .urn'
```{{exec}}

URN 已变为 `...::assets-bucket`，但底层物理资源从未被销毁。

要点：

- 改 logical name = 改 URN = 默认重建。重构资源树（改名、移进/移出 Component）时务必配 `aliases`。
- `aliases` 是**迁移期**的桥梁：完成迁移、确认 state 稳定后，可在后续提交里删掉它。
