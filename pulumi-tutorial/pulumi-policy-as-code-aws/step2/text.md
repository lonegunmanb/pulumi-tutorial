# 运行本地 Policy Pack

现在查看策略包。它包含必需标签、命名前缀和资源数量三类规则。

```bash
cd /root/workspace/policy-as-code-aws/policy-pack && \
cat PulumiPolicy.yaml && \
sed -n '1,220p' index.ts
```{{exec}}

把策略包交给 preview。命令会失败，这是 mandatory 策略在阻止不合规资源。

```bash
source /root/.pulumi-policy-env.sh && \
cd /root/workspace/policy-as-code-aws/app && \
pulumi preview --policy-pack ../policy-pack || true
```{{exec}}

观察输出中的 Policy Violations。mandatory 会阻断计划；advisory 只给出提示。