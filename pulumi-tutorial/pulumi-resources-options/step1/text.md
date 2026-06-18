# 资源的四种身份

先启动 MiniStack（本地 AWS 模拟器），确认健康后部署初始程序：

```bash
cd /root/workspace && \
docker compose up -d && \
curl -s http://localhost:4566/_ministack/health | jq . && \
pulumi up --yes
```{{exec}}

初始程序在 `index.ts` 里声明了两个 S3 Bucket：

- `media-bucket`：只给了 logical name，未指定物理名 → 由 provider **auto-name**（带随机后缀）。
- `data-bucket`：用 `bucket: "resources-lab-data"` **显式指定**了固定物理名。

部署完成后，对照看一个资源的四种身份：

```bash
pulumi stack output && \
pulumi stack export | jq '.deployment.resources[] | select(.type=="aws:s3/bucket:Bucket") | {urn, id, physicalName: .outputs.bucket}'
```{{exec}}

逐一对应：

- **logical name**：`media-bucket` —— 你在代码里起的名字（输出 `mediaLogical`）。
- **physical name**：`mediaPhysical` 形如 `media-bucket-xxxxxxx`，随机后缀来自 auto-naming。
- **physical ID**：`mediaId`，由 provider 创建后返回，`pulumi import` 与 `get` 都认它。
- **URN**：`urn:pulumi:dev::pulumi-resources-options::aws:s3/bucket:Bucket::media-bucket`，Pulumi 内部全局唯一标识。

注意 `data-bucket` 的 physical name 就是固定的 `resources-lab-data`——它放弃了随机后缀，也因此失去了天然的防撞名保护，这正是下一步要处理的问题。