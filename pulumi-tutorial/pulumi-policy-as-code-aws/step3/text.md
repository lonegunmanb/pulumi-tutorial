# 修复资源并重新预览

切换到合规版本。这个版本补齐了 owner 和 managedBy 标签，并使用了策略要求的命名前缀。

```bash
cd /root/workspace/policy-as-code-aws/app && \
cp variants/good.ts index.ts && \
cat index.ts
```{{exec}}

再次运行带策略包的 preview。此时资源级 mandatory 策略应该通过。

```bash
source /root/.pulumi-policy-env.sh && \
cd /root/workspace/policy-as-code-aws/app && \
pulumi preview --policy-pack ../policy-pack
```{{exec}}

你仍会看到策略包运行记录。通过的策略不会制造噪声，但它们已经参与了这次检查。