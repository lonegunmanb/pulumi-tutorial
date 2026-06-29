# 生成 AVM 模块 SDK

现在第一次执行 package 生成。这个命令会下载 Azure Verified Module 并生成本地 SDK，首次运行可能需要等待几分钟。

```bash
source /root/.pulumi-terraform-modules-azure-env.sh && \
cd /root/workspace/terraform-modules-azure && \
pulumi package add terraform-module Azure/avm-res-network-virtualnetwork/azurerm 0.19.0 avmvnet && \
npm install --no-audit --no-fund
```{{exec}}

查看项目文件和本地 SDK：

```bash
cat Pulumi.yaml && \
echo '--- generated sdks ---' && \
find sdks -maxdepth 3 -type f | sort | sed -n '1,40p'
```{{exec}}

这里的模块来源是 Azure Verified Module。Pulumi 生成的 SDK 让 TypeScript 程序可以直接导入 module package。