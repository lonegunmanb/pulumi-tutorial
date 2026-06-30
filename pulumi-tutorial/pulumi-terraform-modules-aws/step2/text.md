# 生成 Terraform Module SDK

现在第一次执行 package 生成。这个命令会下载 Registry 模块、准备 OpenTofu 执行器并生成本地 SDK，首次运行可能需要等待几分钟。

本实验通过环境变量让 Terraform Module provider 使用 OpenTofu 执行器；如果没有这个设置，它会默认寻找 terraform 命令。

```bash
source /root/.pulumi-terraform-modules-aws-env.sh && \
cd /root/workspace/terraform-modules-aws && \
pulumi package add terraform-module terraform-aws-modules/vpc/aws 6.6.1 vpcmod && \
npm install --no-audit --no-fund
```{{exec}}

查看项目文件和生成目录：

```bash
cat Pulumi.yaml && \
echo '--- generated sdks ---' && \
find sdks -maxdepth 3 -type f | sort | sed -n '1,40p'
```{{exec}}

重点看 packages 段。它记录了模块来源、版本和生成包名。

团队成员克隆项目后，可以用 `pulumi install` 补齐这些本地 SDK。