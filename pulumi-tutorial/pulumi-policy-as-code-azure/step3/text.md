# 修复资源并重新预览

切换到合规版本。这个版本使用 eastus，并补齐 owner 和 managedBy 标签。

```bash
cd /root/workspace/policy-as-code-azure/app && \
cp variants/good.ts index.ts && \
cat index.ts
```{{exec}}

再次运行带策略包的 preview。此时资源级 mandatory 策略应该通过。

```bash
source /root/.pulumi-policy-env.sh && \
cd /root/workspace/policy-as-code-azure/app && \
pulumi preview --policy-pack ../policy-pack
```{{exec}}

本地策略包可以检查 Azure 资源，即使这个 Pulumi 程序运行在本地 miniblue 上。