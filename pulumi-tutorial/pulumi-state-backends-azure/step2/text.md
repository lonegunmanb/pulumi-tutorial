# 部署 dev Stack

先看当前 Pulumi 程序。它只创建一个随机名称资源，并导出几个 Stack Output。

```bash
cd /root/workspace/state-backends-azure && \
cat index.ts
```{{exec}}

创建 dev Stack，设置普通配置与机密配置，然后执行部署。

```bash
source /root/.pulumi-state-env.sh && \
cd /root/workspace/state-backends-azure && \
(pulumi stack select dev 2>/dev/null || pulumi stack init dev) && \
pulumi config set service catalog && \
pulumi config set owner platform-team && \
pulumi config set --secret operatorToken dev-token-123 && \
pulumi up --yes && \
pulumi stack output
```{{exec}}

部署完成后，当前 Stack 的 checkpoint 已经写入 Azure Blob Backend。机密配置会以密文形式进入 State，而不是以明文写入容器。
