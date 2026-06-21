# 部署 prod 的扩展形态

现在切到 prod 做预览。这个环境的配置会创建 2 个数据桶，并额外创建访问日志桶：

```bash
cd /root/workspace && \
pulumi stack select prod && \
pulumi preview
```{{exec}}

确认新增资源符合配置矩阵后部署：

```bash
pulumi up --yes && \
pulumi stack output
```{{exec}}

看一下 MiniStack 中的真实桶列表：

```bash
awslocal s3 ls
```{{exec}}

再读取 prod 的清单对象，确认它记录了当前环境的资源形态：

```bash
BUCKET=$(pulumi stack output primaryBucket) && \
awslocal s3 cp "s3://$BUCKET/manifest.json" -
```{{exec}}

最后对比两个 Stack 的输出。资源来自同一份程序，但形态由各自配置决定：

```bash
echo '--- dev ---' && pulumi stack output --stack dev dataBucketNames && \
echo '--- prod ---' && pulumi stack output --stack prod dataBucketNames
```{{exec}}
