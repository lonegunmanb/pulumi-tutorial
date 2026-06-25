# 补齐配置并查看程序日志

现在补齐 Stack 配置，再打开程序调试日志。`--debug` 会显示 pulumi.log.debug 输出。

```bash
source /root/.pulumi-debugging-aws-env.sh && \
cd /root/workspace/debugging-aws && \
pulumi config set owner platform-team && \
pulumi config set environment dev && \
pulumi preview --debug --diff
```{{exec}}

预览通过后执行更新。更新完成后，用 awslocal 查询真实 Bucket 标签。

```bash
source /root/.pulumi-debugging-aws-env.sh && \
cd /root/workspace/debugging-aws && \
pulumi up --yes --debug --diff && \
BUCKET=$(pulumi stack output bucketName) && \
awslocal s3api get-bucket-tagging --bucket "$BUCKET"
```{{exec}}

到这里为止，程序目标状态、State 和 MiniStack 里的真实资源是一致的。