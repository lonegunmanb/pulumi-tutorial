# FileArchive：把目录变成代码包

Archive 表示一组文件。本步把本地 lambda-file 目录作为 FileArchive 传给 Lambda Function 的 code 输入。

先查看 Lambda 代码目录和 Pulumi 程序：

```bash
cd /root/workspace && \
find lambda-file -maxdepth 2 -type f -print -exec sed -n '1,120p' {} \; && \
cat variants/step2-file-archive.ts
```{{exec}}

切换入口程序并部署：

```bash
cp variants/step2-file-archive.ts index.ts && \
pulumi up --yes && \
pulumi stack output
```{{exec}}

调用函数，确认 MiniStack 运行的是这个目录里的 handler：

```bash
FN=$(pulumi stack output functionName) && \
awslocal lambda invoke \
  --function-name "$FN" \
  --cli-binary-format raw-in-base64-out \
  --payload '{}' \
  /tmp/lambda-out.json >/dev/null && \
cat /tmp/lambda-out.json && \
printf '\n'
```{{exec}}

返回值里的 packageKind 应该是 FileArchive。也就是说，Pulumi 已经把目录内容打包并交给了 Lambda 资源。

要点：FileArchive 可以指向目录，也可以指向受支持的本地归档文件。生产项目通常先由构建工具产出目录或 ZIP，再让 Pulumi 引用它。