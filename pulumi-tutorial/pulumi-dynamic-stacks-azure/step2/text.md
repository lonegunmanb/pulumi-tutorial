# 部署 dev 的单子网网络

先对 dev 做变更审查。这个环境应该创建 Resource Group、Virtual Network 和一个应用子网：

```bash
cd /root/workspace && \
pulumi stack select dev && \
pulumi preview
```{{exec}}

确认计划符合预期后再部署：

```bash
pulumi up --yes && \
pulumi stack output
```{{exec}}

注意 tokenHint 会被遮蔽。它来自 secret 配置，即使只是派生字符串，也会继续保持机密性。

读取网络计划输出，确认 dev 只有一个子网：

```bash
pulumi stack output networkPlan | jq
```{{exec}}

再从 miniblue 查询真实 Resource Group 标签：

```bash
RG=$(pulumi stack output resourceGroupName) && \
curl -s "http://localhost:4566/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/$RG" | jq .
```{{exec}}
