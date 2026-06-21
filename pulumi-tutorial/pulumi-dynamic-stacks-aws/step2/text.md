# 部署 dev 的轻量形态

先对 dev 做变更审查。这个环境应该只创建 1 个数据桶和 1 个清单对象，不会创建访问日志桶：

```bash
cd /root/workspace && \
pulumi stack select dev && \
pulumi preview
```{{exec}}

确认计划符合预期后再部署：

```bash
pulumi up --yes && \
pulumi stack output
```{{exec}}

注意输出里的 tokenHint 会被遮蔽。它只是由 secret 派生出来的字符串，但 Pulumi 会继续保留机密性。

现在从 MiniStack 里读取清单对象。这个对象引用了数据桶的输出，所以 Pulumi 会先创建桶，再写入对象：

```bash
BUCKET=$(pulumi stack output primaryBucket) && \
awslocal s3 cp "s3://$BUCKET/manifest.json" -
```{{exec}}

这就是动态配置的第一层效果：dev 的资源集合较小，程序没有为了 dev 复制第二份代码。
