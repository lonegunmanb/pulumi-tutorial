# 查看状态并清理

查看 Pulumi state 中与 Terraform Module 相关的记录：

```bash
source /root/.pulumi-terraform-modules-azure-env.sh && \
cd /root/workspace/terraform-modules-azure && \
pulumi stack export | jq -r '.deployment.resources[] | [.type, .urn] | @tsv' | grep -E 'terraform|avmvnet|tutorial-vnet' || true
```{{exec}}

模块边界进入了 Pulumi state。模块内部资源的生命周期由 Terraform Module provider 和 OpenTofu 处理。

最后销毁模块创建的 VNet，并移除 Stack：

```bash
pulumi destroy --yes && \
pulumi stack rm dev --yes
```{{exec}}

预创建的 Resource Group 和 MiniBlue 容器会由实验环境回收。