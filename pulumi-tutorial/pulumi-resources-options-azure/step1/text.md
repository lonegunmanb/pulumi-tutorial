# 资源的四种身份

环境初始化时已经启动 miniblue（本地 Azure 模拟器）并把它的 metadata 证书加入了系统信任库，可以直接开始。

先看一眼初始程序声明了什么：

```bash
cat /root/workspace/index.ts
```{{exec}}

它在 `index.ts` 里声明了两个 Resource Group：

- `media-rg`：只给了 logical name，未指定物理名 → 由 provider **auto-name**（带随机后缀）。
- `data-rg`：用 `name: "resources-lab-data-rg"` **显式指定**了固定物理名。

并通过 `export` 把这两个组的 logical name、physical name、physical ID 暴露成 stack output，方便对照。

部署初始程序：

```bash
cd /root/workspace && pulumi up --yes
```{{exec}}

部署完成后，对照看一个资源的四种身份：

```bash
pulumi stack output && \
pulumi stack export | jq '.deployment.resources[] | select(.type=="azure:core/resourceGroup:ResourceGroup") | {urn, id, physicalName: .outputs.name}'
```{{exec}}

逐一对应：

- **logical name**：`media-rg` —— 你在代码里起的名字（输出 `mediaLogical`）。
- **physical name**：`mediaPhysical` 形如 `media-rg-xxxxxxx`，随机后缀来自 auto-naming。
- **physical ID**：`mediaId`，这里是完整的 ARM resource ID（`/subscriptions/.../resourceGroups/...`），`pulumi import` 与 `get` 都认它。
- **URN**：`urn:pulumi:dev::pulumi-resources-options-azure::azure:core/resourceGroup:ResourceGroup::media-rg`，Pulumi 内部全局唯一标识。

注意 `data-rg` 的 physical name 就是固定的 `resources-lab-data-rg`——它放弃了随机后缀，也因此失去了天然的防撞名保护，这正是下一步要处理的问题。
