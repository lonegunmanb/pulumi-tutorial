# 用 refresh 发现标签漂移

现在模拟一次控制台外改动。我们直接调用 miniblue，把 prod Resource Group 的标签改掉：

```bash
cd /root/workspace && \
RG=$(pulumi stack output resourceGroupName --stack prod) && \
curl -s -X PUT "http://localhost:4566/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/$RG" -H 'Content-Type: application/json' -d '{"location":"eastus","tags":{"owner":"portal-change","environment":"prod","managedBy":"manual"}}' | jq .
```{{exec}}

真实资源已经偏离代码声明。先只刷新 Resource Group，让 State 读取当前真实标签：

```bash
RG_URN=$(pulumi stack export --stack prod | jq -r '.deployment.resources[] | select(.type == "azure:core/resourceGroup:ResourceGroup" and (.urn | endswith("::workload-rg"))) | .urn') && \
pulumi refresh --yes --stack prod --target "$RG_URN"
```{{exec}}

这里刻意使用 targeted refresh。本实验只手工改了 Resource Group 标签，因此没有必要刷新整棵资源树。

如果使用全量 refresh，provider 还会读回 VNet。这个实验的子网建模在 VNet 的内联字段里，而 miniblue 的读接口不会把该字段按 azurerm 期望的形状完整返回，State 会把子网字段记成缺失，下一次 preview 才会出现 VNet 的 subnets diff。

接着运行 preview。它会显示为了回到配置声明，需要把标签改回去：

```bash
pulumi preview --stack prod
```{{exec}}

确认后执行修复，并再次查询真实标签：

```bash
pulumi up --yes --stack prod && \
RG=$(pulumi stack output resourceGroupName --stack prod) && \
curl -s "http://localhost:4566/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/$RG" | jq .tags
```{{exec}}

这一步的重点是顺序：refresh 先更新 State 对真实世界的认识，preview 再告诉你代码目标状态和真实世界之间的差异。
