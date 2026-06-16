# 导出 State 并观察 Outputs

导出 `prod` Stack 的本地状态快照：

```bash
cd /root/workspace/azure-infra && \
pulumi stack select prod && \
pulumi stack export --file prod-state.json && \
jq '.deployment.resources[] | {urn, type, id}' prod-state.json
```{{exec}}

查看 Stack Outputs 在状态中的记录：

```bash
jq '.deployment.resources[] | select(.type == "pulumi:pulumi:Stack") | .outputs' prod-state.json
```{{exec}}

确认 Secret 没有以明文写进 Stack 配置文件：

```bash
grep -n "prod-password-456" Pulumi.prod.yaml || echo "Secret is encrypted in Pulumi.prod.yaml"
```{{exec}}

State 文件包含资源细节和输出结构。学习阶段可以导出观察，生产中要把它当敏感运维文件处理。