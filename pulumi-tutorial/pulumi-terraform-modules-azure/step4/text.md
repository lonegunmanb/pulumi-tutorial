# 扩展子网配置

现在把模块输入从两个子网扩展到三个子网。先切换变体并预览：

```bash
source /root/.pulumi-terraform-modules-azure-env.sh && \
cd /root/workspace/terraform-modules-azure && \
cp variants/expanded.ts index.ts && \
pulumi preview
```{{exec}}

如果计划显示新增 data 子网，就执行更新：

```bash
pulumi up --yes && \
pulumi stack output subnetMap | jq
```{{exec}}

确认扩展后的子网数量：

```bash
pulumi stack output subnetMap | jq 'keys | length'
```{{exec}}

再次查询 MiniBlue，观察 VNet 资源内容：

```bash
VNET_ID=$(pulumi stack output virtualNetworkId) && \
curl -s "https://localhost:4567${VNET_ID}?api-version=2024-07-01" | jq .
```{{exec}}

这一步修改的是模块输入里的 subnets map，而不是手写单个 Azure 子网资源。