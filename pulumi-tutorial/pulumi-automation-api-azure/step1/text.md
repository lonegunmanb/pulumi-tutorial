# 运行 CLI 基线

先确认 miniblue 已经启动并通过健康检查，再用 CLI 执行同一份 Pulumi 程序。这样可以确认 Pulumi 项目、Stack 配置和本地 Azure 模拟器都已经可用。

```bash
cd /root/workspace && \
docker compose up -d && \
for _ in $(seq 1 120); do curl -sk "https://localhost:4567/metadata/endpoints?api-version=2019-05-01" >/dev/null 2>&1 && break; sleep 2; done && \
curl -sk "https://localhost:4567/metadata/endpoints?api-version=2019-05-01" | jq . && \
pulumi stack select dev && \
pulumi preview && \
pulumi up --yes && \
pulumi stack output --json && \
pulumi destroy --yes
```{{exec}}

这一步完成后，dev Stack 仍然存在，但里面的资源已经删除。下一步会由 Automation API 接管同一个工作区。