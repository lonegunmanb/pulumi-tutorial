# 导出 State 并观察 Outputs

这一步我们要深入理解 Pulumi 的内部"大脑"——State 文件。State 是一个 JSON 文件，包含了上一次部署后所有资源的属性和状态。Pulumi 通过对比新代码和旧 State，才能判断什么需要创建、修改或删除。

先导出 `prod` Stack 的状态快照到 JSON 文件，并查看其中的资源信息：

```bash
cd /root/workspace/azure-infra && \
pulumi stack select prod && \
pulumi stack export --file prod-state.json && \
jq '.deployment.resources[] | {urn, type, id}' prod-state.json
```{{exec}}

现在查看这个 State 中的 Outputs——这些是 Stack 导出给外部使用的值：

```bash
jq '.deployment.resources[] | select(.type == "pulumi:pulumi:Stack") | .outputs' prod-state.json
```{{exec}}

最后确认 Secret 没有以明文形式存储在配置文件中（Pulumi 会加密存储）：

```bash
grep -n "prod-password-456" Pulumi.prod.yaml || echo "Secret is encrypted in Pulumi.prod.yaml"
```{{exec}}

关键理解：
- **State 文件**：包含所有资源的详细信息（类型、ID、属性等）以及 Outputs。这是 Pulumi 的"记忆"，生产环境中需要妥善保管，如同对待敏感数据。
- **Outputs**：Stack 暴露给外部使用的值，例如创建的资源 ID、访问地址等。下一步我们会看到，另一个 Project 可以通过 StackReference 读取这些 Outputs。
- **Secret 加密**：即使你设置了密钥，它在本地文件系统中也是加密的，不会明文显示。