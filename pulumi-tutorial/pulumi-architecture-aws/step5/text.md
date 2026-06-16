# 修改期望状态

现在只修改 `media-bucket` 的标签，观察 Pulumi 如何从 `create` 变成 `update`：

```bash
cd /root/workspace && \
sed -i 's/stage: "first-up"/stage: "updated-in-place"/' index.ts && \
pulumi preview
```{{exec}}

确认预览后执行更新（`pulumi up` 与查询拆成两个代码块分别点击）：

```bash
pulumi up --yes
```{{exec}}

```bash
pulumi stack export | jq -r '.deployment.resources[] | select(.type=="aws:s3/bucket:Bucket") | .outputs.tags'
```{{exec}}

这说明 Pulumi 每次都会重新运行程序，拿“新图纸”和“旧档案”比较，然后只执行必要变更。