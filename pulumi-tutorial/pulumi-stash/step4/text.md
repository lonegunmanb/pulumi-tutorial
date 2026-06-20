# 保存复杂值与 secret

Stash 不只能保存字符串，也能保存对象、数组和被标记为 secret 的值。切换到新的程序变体：

```bash
cd /root/workspace && \
cp variants/complex-secret.ts index.ts && \
cat index.ts
```{{exec}}

执行部署并查看 Stack Output：

```bash
cd /root/workspace && \
pulumi up --yes --non-interactive && \
pulumi stack output
```{{exec}}

复杂对象会按结构输出。被标记为 secret 的值会显示为 [secret]，并以加密形式保存在 state 中。

只有在明确需要查看明文时，才使用显示 secret 的参数：

```bash
cd /root/workspace && \
pulumi stack output stashedToken --show-secrets
```{{exec}}

在团队环境中，应谨慎执行这类命令。显示出来的明文与真实凭据没有区别。