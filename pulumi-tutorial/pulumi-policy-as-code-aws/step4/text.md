# 用策略执行更新

最后在 up 阶段也带上策略包。这样即使有人跳过 preview，更新前仍会执行同一组规则。

先故意切回不合规版本，确认 `pulumi up` 会被 mandatory 策略拦下。

```bash
source /root/.pulumi-policy-env.sh && \
cd /root/workspace/policy-as-code-aws/app && \
cp variants/bad.ts index.ts && \
pulumi up --yes --policy-pack ../policy-pack || true
```{{exec}}

现在切回合规版本，再执行真正的更新。

```bash
source /root/.pulumi-policy-env.sh && \
cd /root/workspace/policy-as-code-aws/app && \
cp variants/good.ts index.ts && \
pulumi up --yes --policy-pack ../policy-pack && \
pulumi stack output
```{{exec}}

导出状态，确认 Stack 中已经创建了符合策略的 S3 Bucket。

```bash
cd /root/workspace/policy-as-code-aws/app && \
pulumi stack export | jq '.deployment.resources[] | select(.type=="aws:s3/bucket:Bucket") | {urn, bucket: .outputs.bucket, tags: .outputs.tags}'
```{{exec}}

本地 Policy Pack 必须在命令中显式传入。Pulumi Cloud 的 Policy Groups 才会自动把策略应用到一批 Stack。