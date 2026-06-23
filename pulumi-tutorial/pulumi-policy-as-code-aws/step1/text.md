# 预览未加策略的资源

先查看当前程序。它声明了一个 S3 Bucket，但故意少写了部分标签，并使用了临时命名。

```bash
source /root/.pulumi-policy-env.sh && \
cd /root/workspace/policy-as-code-aws/app && \
cat index.ts
```{{exec}}

不带策略包时，Pulumi 只根据程序和 provider 生成计划。

```bash
source /root/.pulumi-policy-env.sh && \
cd /root/workspace/policy-as-code-aws/app && \
(pulumi stack select dev 2>/dev/null || pulumi stack init dev) && \
pulumi preview
```{{exec}}

这一步说明：如果没有策略检查，命名和标签问题不会自动被 Pulumi 阻止。