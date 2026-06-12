# 完成 Azure / miniblue 版实验

清理资源和容器：

```bash
cd /root/workspace
source venv/bin/activate
export PULUMI_CONFIG_PASSPHRASE=""
echo "Destroy 前 State 中的资源数量："
pulumi stack export | jq '.deployment.resources | length'
pulumi destroy --yes
echo "Destroy 后 State 中的资源数量："
pulumi stack export | jq '.deployment.resources | length'
docker compose down
```{{exec}}

你已经通过 miniblue 观察到：Provider 可以是官方云 Provider，也可以是自己编写的 Dynamic Provider。关键是它要响应 Engine 的资源生命周期操作。