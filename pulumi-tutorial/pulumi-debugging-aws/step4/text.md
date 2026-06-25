# 用 refresh 识别漂移

现在模拟一次控制台外改动。我们不用 Pulumi，而是直接调用 awslocal 修改 Bucket 标签。

```bash
source /root/.pulumi-debugging-aws-env.sh && \
cd /root/workspace/debugging-aws && \
BUCKET=$(pulumi stack output bucketName) && \
awslocal s3api put-bucket-tagging --bucket "$BUCKET" --tagging '{"TagSet":[{"Key":"owner","Value":"console-change"},{"Key":"environment","Value":"dev"},{"Key":"diagnostic","Value":"manual"},{"Key":"managedBy","Value":"manual"}]}' && \
awslocal s3api get-bucket-tagging --bucket "$BUCKET"
```{{exec}}

普通 preview 只比较程序和 State。它通常不会主动读取真实资源，所以这一步未必能发现刚才的手工改动。

```bash
source /root/.pulumi-debugging-aws-env.sh && \
cd /root/workspace/debugging-aws && \
pulumi preview --diff
```{{exec}}

现在先预览 refresh。它会从 MiniStack 读取真实资源，并显示 State 将如何变化。

```bash
source /root/.pulumi-debugging-aws-env.sh && \
cd /root/workspace/debugging-aws && \
pulumi refresh --preview-only --diff
```{{exec}}

确认后执行 refresh，再用 up 把真实标签恢复到代码声明。

```bash
source /root/.pulumi-debugging-aws-env.sh && \
cd /root/workspace/debugging-aws && \
pulumi refresh --yes && \
pulumi preview --diff && \
pulumi up --yes --diff && \
BUCKET=$(pulumi stack output bucketName) && \
awslocal s3api get-bucket-tagging --bucket "$BUCKET"
```{{exec}}

顺序很关键：refresh 更新 State 对真实资源的认识，preview 再判断是否需要回到程序声明。