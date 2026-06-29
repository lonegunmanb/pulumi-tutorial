# 查看项目与模块代码

MiniStack 已经在后台启动。先查看健康检查、项目文件和当前 Pulumi 程序。

```bash
source /root/.pulumi-terraform-modules-aws-env.sh && \
cd /root/workspace/terraform-modules-aws && \
curl -s http://localhost:4566/_ministack/health | jq . && \
echo '--- Pulumi.yaml ---' && \
cat Pulumi.yaml && \
echo '--- index.ts ---' && \
sed -n '1,180p' index.ts
```{{exec}}

这段程序没有使用 Pulumi 原生 AWS 资源，而是导入生成后的 module package，然后创建一个 VPC 模块实例。

注意 provider 配置里的 endpoint，它把 Terraform AWS provider 的 EC2 和 STS 调用指向本地 MiniStack。