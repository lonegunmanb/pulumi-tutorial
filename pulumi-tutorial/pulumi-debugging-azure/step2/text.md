# 补齐配置并查看程序日志

现在补齐 Stack 配置，并切换到真实资源程序。`--debug` 会显示 pulumi.log.debug 输出。

```bash
source /root/.pulumi-debugging-azure-env.sh && \
cd /root/workspace/debugging-azure && \
pulumi config set owner platform-team && \
pulumi config set environment dev && \
pulumi config set location eastus && \
cp variants/resource.ts index.ts && \
sed -n '1,180p' index.ts && \
pulumi preview --debug --diff
```{{exec}}

预览通过后执行更新。更新完成后，用 miniblue API 查询真实 Resource Group 标签。

```bash
source /root/.pulumi-debugging-azure-env.sh && \
cd /root/workspace/debugging-azure && \
pulumi up --yes --debug --diff && \
RG=$(pulumi stack output resourceGroupName) && \
curl -s "http://localhost:4566/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/$RG" | jq .tags
```{{exec}}

到这里为止，程序目标状态、State 和 miniblue 里的真实资源是一致的。