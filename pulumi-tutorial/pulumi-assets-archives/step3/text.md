# AssetArchive：组合一个包

AssetArchive 用一个 map 描述最终包内的文件结构。这个 map 的值既可以是 Asset，也可以是 Archive。

先看这一步的程序：

```bash
cd /root/workspace && cat variants/step3-asset-archive.ts
```{{exec}}

这个包里有三类内容：index.js 来自 StringAsset，message.txt 来自 FileAsset，public 目录来自 FileArchive。程序用 __dirname 定位包内文件，避免不同运行时的工作目录差异。

应用它并再次调用 Lambda：

```bash
cp variants/step3-asset-archive.ts index.ts && \
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

返回值里的 message 来自包内的 message.txt，hasPublicFolder 为 true，说明 public 目录也被打进去了。

要点：AssetArchive 很适合小型组合包和教程演示。真实应用代码较大时，仍建议交给专门的构建流程。
