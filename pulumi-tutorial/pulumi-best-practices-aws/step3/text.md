# 受限输入：控制 dev 成本

组件把规格收敛成 dev 和 standard 两个选择。dev 环境只能使用 dev 规格，所以错误会在程序构造阶段出现。

切换到故意错误的变体：

```bash
source /root/.pulumi-best-practices-aws-env.sh && \
cd /root/workspace/best-practices-aws/workload && \
cp variants/too-expensive.ts index.ts && \
sed -n '1,160p' index.ts
```{{exec}}

运行 preview。命令会失败，这是组件在阻止 dev 环境使用 standard 规格。

```bash
pulumi preview || true
```{{exec}}

恢复合规版本，确认 preview 可以继续生成计划：

```bash
cp variants/good.ts index.ts && \
pulumi preview
```{{exec}}

这一步体现的是成本控制的第一层：用受限输入让错误尽早暴露，而不是等到底层云 API 才报错。