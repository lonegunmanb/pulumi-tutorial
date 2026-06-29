# 部署 VPC 模块

先做 preview。这里的资源来自 Terraform Module 内部，但更新仍由 Pulumi Stack 驱动。

```bash
source /root/.pulumi-terraform-modules-aws-env.sh && \
cd /root/workspace/terraform-modules-aws && \
pulumi preview
```{{exec}}

确认计划后部署，并查看模块输出：

```bash
pulumi up --yes && \
pulumi stack output
```{{exec}}

再从 MiniStack 查询真实 VPC 和子网：

```bash
echo '--- vpcs ---' && \
awslocal ec2 describe-vpcs | jq '.Vpcs[] | {VpcId, CidrBlock, Tags}' && \
echo '--- subnets ---' && \
awslocal ec2 describe-subnets | jq '.Subnets[] | {SubnetId, VpcId, CidrBlock, AvailabilityZone}'
```{{exec}}

这一步说明模块输出已经回到 Pulumi，真实资源则由 Terraform AWS provider 写入 MiniStack。