# 运行 CLI 基线

先用 CLI 执行同一份 Pulumi 程序。这样可以确认 Pulumi 项目、Stack 配置和 miniblue 都已经可用。

```bash
cd /root/workspace && \
pulumi stack select dev && \
pulumi preview && \
pulumi up --yes && \
pulumi stack output --json && \
pulumi destroy --yes
```{{exec}}

这一步完成后，dev Stack 仍然存在，但里面的资源已经删除。下一步会由 Automation API 接管同一个工作区。