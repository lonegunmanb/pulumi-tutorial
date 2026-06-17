# 导出 State 并观察 Outputs

这一步要认识两个特别重要的概念：**State** 和 **Output**。

- **State** 可以理解成 Pulumi 的“部署档案”或“记忆”。它记录了这个 Stack 已经创建过哪些资源、这些资源的标识和属性是什么。
- **Output** 是这个 Stack 主动对外暴露的结果，例如 Bucket 名称、交接信息、可供下游项目继续使用的值。

先导出 `prod` Stack 的本地状态快照：

```bash
cd /root/workspace/aws-infra && \
pulumi stack select prod && \
pulumi stack export --file prod-state.json && \
jq '.deployment.resources[] | {urn, type, id}' prod-state.json
```{{exec}}

接着查看 State 里保存的 Stack Outputs：

```bash
jq '.deployment.resources[] | select(.type == "pulumi:pulumi:Stack") | .outputs' prod-state.json
```{{exec}}

再确认 Secret 没有以明文写进 Stack 配置文件：

```bash
grep -n "prod-token-456" Pulumi.prod.yaml || echo "Secret is encrypted in Pulumi.prod.yaml"
```{{exec}}

不要把 `prod-state.json` 提交到 Git。State 文件包含资源细节和输出结构，应按敏感运维文件处理。

这一步的核心理解是：**Pulumi 不是只会“跑一遍代码”就结束，它会把执行结果持续记录下来。** 下次再运行时，Pulumi 就是拿“新代码”和“旧 State”做比较，决定该创建、更新还是删除。