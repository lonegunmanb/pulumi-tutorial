# 完成 AWS / MiniStack 版实验

清理资源和容器：

```bash
cd /root/workspace
echo "Destroy 前 State 中的资源数量："
pulumi stack export | jq '.deployment.resources | length'
pulumi destroy --yes
echo "Destroy 后 State 中的资源数量："
pulumi stack export | jq '.deployment.resources | length'
docker compose down
```{{exec}}

你已经观察到 Pulumi 架构中的关键路径：程序注册资源，Engine 计算计划，Provider 调用 MiniStack，State 记录结果。