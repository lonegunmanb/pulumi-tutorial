# 删除声明并清理

现在切换到只保留 media 桶的程序：

```bash
cd /root/workspace && cp variants/step5-delete.ts index.ts && cat index.ts
```{{exec}}

预览删除路径：

```bash
pulumi preview --diff
```{{exec}}

content-bucket 不再出现在程序注册请求里，但它仍然存在于 State 中，所以 Engine 会安排一次 `-` 删除。

执行这次更新：

```bash
pulumi up --yes
```{{exec}}

确认当前只剩一个 Bucket：

```bash
pulumi stack export | jq '.deployment.resources[] | select(.type=="aws:s3/bucket:Bucket") | {urn, physicalName: .outputs.bucket}'
```{{exec}}

可选清理本地资源：

```bash
pulumi destroy --yes && docker compose down
```{{exec}}

到这里，你已经观察了 create、update、逻辑名导致的 create/delete，以及从程序删除资源声明后的 delete。