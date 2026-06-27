# 多个工作负载共享平台

现在用同一份 workload 程序创建第二个工作负载。billing 会读取同一个 platform dev Stack，但拥有自己的 Stack 状态和数据库实例。

```bash
source /root/.pulumi-best-practices-aws-env.sh && \
cd /root/workspace/best-practices-aws/workload && \
{ pulumi stack init billing-dev || pulumi stack select billing-dev; } && \
pulumi config set service billing && \
pulumi config set environment dev && \
pulumi config set size dev && \
pulumi config set platformStack dev && \
pulumi config set --secret dbPassword 'Correct-Horse-2' && \
pulumi up --yes
```{{exec}}

查看 billing 的输出，再切回 orders 对比。两个 Stack 都读取同一个平台契约。

```bash
pulumi stack output dbIdentifier && \
pulumi stack output platformContract && \
pulumi stack select orders-dev && \
pulumi stack output dbIdentifier && \
pulumi stack output platformContract
```{{exec}}

现在你已经完成一条完整路径：平台 Stack 管共享基线，工作负载 Stack 只读引用，组件封装默认值，策略校验最终资源。

MiniStack RDS 在本实验环境里删除实例不够稳定，因此这里不安排清理命令。Killercoda 会在会话结束后回收临时环境。