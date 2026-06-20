# 三种 Asset：字符串、文件、URI

初始程序已经声明了一个 S3 Bucket，并用三种 Asset 创建三个对象。先看程序：

```bash
cd /root/workspace && cat index.ts && cat common.ts
```{{exec}}

重点在 common.ts：一个对象来自 StringAsset，一个对象来自 FileAsset，另一个对象来自 file URI 形式的 RemoteAsset。

部署并查看输出：

```bash
cd /root/workspace && \
pulumi up --yes && \
pulumi stack output
```{{exec}}

现在直接从 MiniStack 的 S3 里读回三个对象内容：

```bash
BUCKET=$(pulumi stack output bucketName) && \
awslocal s3 cp "s3://$BUCKET/notes/string.txt" - && \
printf '\n---\n' && \
awslocal s3 cp "s3://$BUCKET/notes/from-file.txt" - && \
printf '\n---\n' && \
awslocal s3 cp "s3://$BUCKET/notes/from-file-uri.txt" - && \
printf '\n'
```{{exec}}

你会看到三段不同文本。它们进入同一个资源输入 source，但来源不同：字符串、本地文件、file URI。

查看 state 里这几个输入的大致形态：

```bash
pulumi stack export | jq '.deployment.resources[] | select(.type=="aws:s3/bucketObject:BucketObject") | {urn, key: .inputs.key, source: .inputs.source}'
```{{exec}}

要点：Asset 不是独立资源，它只是 S3 Object 的输入。文件内容变化时，变化会体现在引用它的对象资源上。