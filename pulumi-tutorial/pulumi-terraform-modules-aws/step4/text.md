# 修改模块输入

现在把模块输入从两个可用区扩展到三个可用区。先切换到准备好的变体，再看变更计划。

```bash
source /root/.pulumi-terraform-modules-aws-env.sh && \
cd /root/workspace/terraform-modules-aws && \
cp variants/expanded.ts index.ts && \
pulumi preview
```{{exec}}

如果计划显示新增子网和相关网络资源，就执行更新：

```bash
pulumi up --yes && \
pulumi stack output publicSubnetIds && \
pulumi stack output privateSubnetIds
```{{exec}}

再次查询 MiniStack，确认子网数量已经变化：

```bash
awslocal ec2 describe-subnets | jq '.Subnets | length'
```{{exec}}

这里修改的是模块变量，不是直接修改模块内部资源。Pulumi 把新的输入交给 Terraform Module provider，内部资源图由 OpenTofu 执行。