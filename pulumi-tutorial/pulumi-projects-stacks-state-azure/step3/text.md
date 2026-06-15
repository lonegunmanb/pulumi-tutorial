# 复制配置创建 prod Stack

复制 `dev` 配置创建 `prod` Stack，再覆盖环境差异：

```bash
cd /root/workspace/azure-infra
pulumi stack init prod --copy-config-from dev || pulumi stack select prod
pulumi config set owner prod-team
pulumi config set --secret adminPassword prod-password-456
pulumi stack ls
pulumi config
cat Pulumi.prod.yaml
```{{exec}}

部署 `prod`，同一份 Project 会创建另一组命名不同的模拟 Azure 资源：

```bash
pulumi preview
pulumi up --yes
pulumi stack output resource_group
pulumi stack output key_vault
pulumi stack output handoff_card
```{{exec}}

`dev` 与 `prod` 的代码完全相同，差异来自 Stack 名称和 Stack Config。