# 观察远端 .pulumi 目录

现在用 azlocal 列出状态容器中的对象。重点观察 meta、stacks、history 和 locks 这些路径。

```bash
source /root/.pulumi-state-env.sh && \
azlocal storage blob list --account pulumistate --container pulumi-state | \
sed -n '1,120p'
```{{exec}}

这一步会列出多个 blob。dev 和 prod 这两个 Stack 的 checkpoint 会分别出现在 stacks 目录下，history 目录也会按 Stack 保存历史记录。

读取 dev Stack 的 checkpoint，查看其中的资源数量和 Stack Output。

```bash
source /root/.pulumi-state-env.sh && \
azlocal storage blob download --account pulumistate --container pulumi-state --name .pulumi/stacks/state-backends-azure/dev.json | \
jq '(.deployment.resources // .checkpoint.latest.resources // []) as $resources | ($resources[] | select(.type=="pulumi:pulumi:Stack")) as $stack | {resourceCount: ($resources | length), outputs: $stack.outputs}'
```{{exec}}

这就是 Pulumi CLI 平时通过 Backend 读写的 State 文件。真实项目中不要把这个文件当作普通配置文件手工编辑。
