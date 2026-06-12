# 检查配置与状态

```bash
pulumi stack select prod
pulumi preview
pulumi up --yes
pulumi stack export | jq '.deployment.resources[] | {urn, type}'
```{{exec}}

观察状态快照中的 URN、资源类型与输出字段。实验结束后执行：

```bash
pulumi destroy --yes
```{{exec}}