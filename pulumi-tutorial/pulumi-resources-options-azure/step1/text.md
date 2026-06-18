# 资源的四种身份

先启动 miniblue（本地 Azure 模拟器），**信任它的 metadata 证书**，再部署初始程序。

**1) 启动容器并等待 metadata 端口就绪**：

```bash
cd /root/workspace && \
docker compose up -d && \
for _ in $(seq 1 60); do curl -sk https://localhost:4567/metadata/endpoints?api-version=2019-05-01 >/dev/null 2>&1 && break; sleep 2; done && \
echo "miniblue metadata is up"
```{{exec}}

**2) 导出 miniblue 证书并加入系统信任库**（azurerm provider 是 Go 二进制，使用系统 CA）：

```bash
openssl s_client -connect localhost:4567 -servername localhost </dev/null 2>/dev/null \
  | openssl x509 > /usr/local/share/ca-certificates/miniblue.crt && \
update-ca-certificates
```{{exec}}

**3) 部署初始程序**：

```bash
pulumi up --yes
```{{exec}}

初始程序在 `index.ts` 里声明了两个 Resource Group：

- `media-rg`：只给了 logical name，未指定物理名 → 由 provider **auto-name**（带随机后缀）。
- `data-rg`：用 `name: "resources-lab-data-rg"` **显式指定**了固定物理名。

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
