# 用 refresh 发现漂移

现在模拟一次控制台外改动。我们不用 Pulumi，而是直接用本地 AWS CLI 改 prod 主桶标签：

```bash
cd /root/workspace && \
BUCKET=$(pulumi stack output primaryBucket --stack prod) && \
awslocal s3api put-bucket-tagging --bucket "$BUCKET" --tagging '{"TagSet":[{"Key":"owner","Value":"console-change"},{"Key":"environment","Value":"prod"},{"Key":"managedBy","Value":"manual"}]}' && \
awslocal s3api get-bucket-tagging --bucket "$BUCKET"
```{{exec}}

这时真实云资源已经偏离代码声明，但 Pulumi State 还不知道。先运行 refresh，让 State 读取真实资源当前状态：

```bash
pulumi refresh --yes --stack prod
```{{exec}}

接着运行 preview。它会告诉你：如果要回到代码和配置声明的目标状态，需要把标签改回去：

```bash
pulumi preview --stack prod
```{{exec}}

确认后执行修复，再读取标签验证：

```bash
pulumi up --yes --stack prod && \
BUCKET=$(pulumi stack output primaryBucket --stack prod) && \
awslocal s3api get-bucket-tagging --bucket "$BUCKET"
```{{exec}}

这就是 refresh 的常见用法：先承认真实环境发生了什么，再由 preview 判断是否需要恢复到代码目标状态。
