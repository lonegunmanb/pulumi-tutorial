# 查看状态并清理

先导出 Pulumi state，并列出其中的资源类型和 URN。

```bash
source /root/.pulumi-terraform-modules-aws-env.sh && \
cd /root/workspace/terraform-modules-aws && \
pulumi stack export > /tmp/tfmod-aws-state.json && \
jq -r '.deployment.resources[] | [.type, .urn] | @tsv' /tmp/tfmod-aws-state.json | sed -n '1,120p'
```{{exec}}

再只看 Terraform Module provider 发布的内部资源视图。

```bash
jq -r '.deployment.resources[] | select(.type | test(":tf:")) | [.type, .urn] | @tsv' /tmp/tfmod-aws-state.json
```{{exec}}

这些 `:tf:` 资源用于展示模块内部的 VPC、Subnet 和路由资源变化。

最后确认模块内部保存了 Terraform state，但不要把它作为业务接口解析。

```bash
jq -r '.deployment.resources[] | select(.outputs.__state? != null or .outputs.__lock? != null) | {type, urn, hasTerraformState: (.outputs.__state != null), hasLockFile: (.outputs.__lock != null), moduleVersion: .outputs.__moduleVersion}' /tmp/tfmod-aws-state.json
```{{exec}}

要点：Pulumi state 里既有模块边界，也有内部资源视图；真实 Terraform state 存在于模块内部状态字段中。内部视图不能像普通 Pulumi 子资源那样逐个使用 transforms、target 或 protect。

最后清理本次实验资源：

```bash
pulumi destroy --yes && \
pulumi stack rm dev --yes
```{{exec}}

MiniStack 容器会由实验环境回收，不需要手动停止。