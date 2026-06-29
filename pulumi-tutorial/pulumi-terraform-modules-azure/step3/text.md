# 部署 VNet 模块

先做 preview。Terraform Module 内部会使用 Azure provider 调用 MiniBlue。

```bash
source /root/.pulumi-terraform-modules-azure-env.sh && \
cd /root/workspace/terraform-modules-azure && \
pulumi preview
```{{exec}}

确认计划后部署，并查看模块输出：

```bash
pulumi up --yes && \
pulumi stack output
```{{exec}}

用模块输出的资源 ID 查询 MiniBlue：

```bash
VNET_ID=$(pulumi stack output virtualNetworkId) && \
curl -s "http://localhost:4566${VNET_ID}?api-version=2024-07-01" | jq .
```{{exec}}

这说明 Pulumi state 里记录了模块输出，而真实 VNet 由 AVM 模块写入 MiniBlue。