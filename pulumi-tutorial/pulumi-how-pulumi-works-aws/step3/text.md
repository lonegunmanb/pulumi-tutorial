# 标签变化产生 update

现在把程序切换到更新版，只修改 media 桶的标签：

```bash
cd /root/workspace && cp variants/step3-update.ts index.ts && cat index.ts
```{{exec}}

预览这次变化：

```bash
pulumi preview --diff
```{{exec}}

注意 media-bucket 的操作是 `~`。Engine 在 State 中找到了同一个逻辑资源，又通过 Provider 判断标签可以原地修改，所以这不是新建。

执行更新：

```bash
pulumi up --yes
```{{exec}}

查看 State 中的新标签：

```bash
pulumi stack export | jq '.deployment.resources[] | select(.type=="aws:s3/bucket:Bucket" and (.urn | contains("media-bucket"))) | .outputs.tags'
```{{exec}}

这就是 desired state 模型的核心：程序改成新图纸，Engine 用 State 找到旧记录，再计算最小变更。