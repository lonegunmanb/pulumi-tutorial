# 运行本地 Policy Pack

现在查看策略包。它包含必需标签、批准区域、命名前缀和资源数量规则。

```bash
cd /root/workspace/policy-as-code-azure/policy-pack && \
cat PulumiPolicy.yaml && \
sed -n '1,240p' index.ts
```{{exec}}

把策略包交给 preview。命令会失败，这是 mandatory 策略在阻止不合规资源。

```bash
source /root/.pulumi-policy-env.sh && \
cd /root/workspace/policy-as-code-azure/app && \
pulumi preview --policy-pack ../policy-pack || true
```{{exec}}

观察输出中的 Policy Violations。区域和标签策略是 mandatory，命名前缀策略是 advisory。