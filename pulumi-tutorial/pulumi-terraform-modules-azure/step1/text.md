# 查看 MiniBlue 与项目

MiniBlue 已经在后台启动，并预创建了一个 Resource Group。先确认模拟器健康状态和项目文件。

```bash
source /root/.pulumi-terraform-modules-azure-env.sh && \
cd /root/workspace/terraform-modules-azure && \
curl -s http://localhost:4566/health | jq . && \
echo '--- resource group ---' && \
curl -s https://localhost:4567/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/rg-tfmod-vnet | jq . && \
echo '--- index.ts ---' && \
sed -n '1,180p' index.ts
```{{exec}}

这个 Resource Group 不是 Pulumi 管理的资源，而是提供给 AVM 模块的父级容器。

程序中的 parent_id 就是这个 Resource Group 的完整资源 ID。