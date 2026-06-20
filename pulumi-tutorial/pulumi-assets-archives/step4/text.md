# RemoteArchive 与 state 观察

最后一种 Archive 是 RemoteArchive。为了避免依赖外网，本实验使用本地 file URI 指向一个已经准备好的 ZIP 包。

先确认 ZIP 包和程序内容：

```bash
cd /root/workspace && \
unzip -l dist/remote-function.zip && \
cat variants/step4-remote-archive.ts
```{{exec}}

应用 RemoteArchive 版本并调用函数：

```bash
cp variants/step4-remote-archive.ts index.ts && \
pulumi up --yes && \
FN=$(pulumi stack output functionName) && \
awslocal lambda invoke \
  --function-name "$FN" \
  --cli-binary-format raw-in-base64-out \
  --payload '{}' \
  /tmp/lambda-out.json >/dev/null && \
cat /tmp/lambda-out.json && \
printf '\n'
```{{exec}}

返回值里的 packageKind 应该变成 RemoteArchive。这里的 URI 是本地文件，生产环境里也可以换成稳定的 https 地址。

最后观察 Lambda 资源在 state 中保存的 code 输入：

```bash
pulumi stack export | jq '.deployment.resources[] | select(.type=="aws:lambda/function:Function") | {urn, code: .inputs.code, sourceCodeHash: .inputs.sourceCodeHash}'
```{{exec}}

注意：Asset 与 Archive 都只是资源输入。它们不会单独出现在资源树里，但会影响引用它们的资源 diff 和更新。