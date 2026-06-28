# 检查变量替换与配置

查看生成项目里的文件。PROJECT 和 DESCRIPTION 占位符已经被替换成刚才传入的项目名和描述。

```bash
cd /root/workspace/templates-lab/orders-service && \
find . -maxdepth 2 -type f | sort && \
sed -n '1,80p' Pulumi.yaml && \
sed -n '1,120p' README.md && \
sed -n '1,120p' index.ts
```{{exec}}

再看 Stack 配置。apiToken 来自 template config，并且会作为 secret 保存。

```bash
pulumi config && \
pulumi config get apiToken -j | jq .
```{{exec}}

如果 JSON 里的 secret 字段是 true，说明 apiToken 已经作为 Pulumi secret 写入 Stack 配置。
