# 预览并部署资源

先让 Engine 读取程序并计算计划：

```bash
cd /root/workspace
pulumi preview
```{{exec}}

如果预览中只看到创建 S3 Bucket 的计划，就执行部署：

```bash
pulumi up --yes
pulumi stack output
```{{exec}}

观察输出中的 `+` 符号。它表示 Engine 判断这些资源在旧 State 中不存在，需要创建。