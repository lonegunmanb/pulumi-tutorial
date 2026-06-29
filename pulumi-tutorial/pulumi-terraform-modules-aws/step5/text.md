# 查看状态并清理

先看 Pulumi state 中与 Terraform Module 相关的资源记录。

```bash
source /root/.pulumi-terraform-modules-aws-env.sh && \
cd /root/workspace/terraform-modules-aws && \
pulumi stack export | jq -r '.deployment.resources[] | [.type, .urn] | @tsv' | grep -E 'terraform|vpcmod|tutorial-vpc' || true
```{{exec}}

你会看到模块边界本身进入了 Pulumi state。模块内部资源也会由 provider 写入状态，但不能像普通 Pulumi 子资源那样逐个使用 transforms 或 protect。

最后清理本次实验资源：

```bash
pulumi destroy --yes && \
pulumi stack rm dev --yes
```{{exec}}

MiniStack 容器会由实验环境回收，不需要手动停止。