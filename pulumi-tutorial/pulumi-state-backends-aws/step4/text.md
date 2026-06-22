# 观察远端 .pulumi 目录

现在用 awslocal 列出状态 bucket 中的对象。重点观察 meta、stacks、history 和 locks 这些路径。

```bash
source /root/.pulumi-state-env.sh && \
awslocal s3api list-objects-v2 --bucket pulumi-state-aws --prefix .pulumi/ --query 'Contents[].Key' --output text | \
tr '\t' '\n'
```{{exec}}

这一步会列出多个对象。dev 和 prod 这两个 Stack 的 checkpoint 会分别出现在 stacks 目录下，history 目录也会按 Stack 保存历史记录。

读取 dev Stack 的 checkpoint，查看其中的资源数量和 Stack Output。

```bash
source /root/.pulumi-state-env.sh && \
awslocal s3 cp s3://pulumi-state-aws/.pulumi/stacks/state-backends-aws/dev.json - | \
jq '(.deployment.resources // .checkpoint.latest.resources // []) as $resources | ($resources[] | select(.type=="pulumi:pulumi:Stack")) as $stack | {resourceCount: ($resources | length), outputs: $stack.outputs}'
```{{exec}}

这就是 Pulumi CLI 平时通过 Backend 读写的 State 文件。真实项目中不要把这个文件当作普通配置文件手工编辑。
