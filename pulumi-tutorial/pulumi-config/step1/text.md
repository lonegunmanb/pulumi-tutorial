# 用 CLI 存取配置与命名空间

MiniStack（本地 AWS 模拟器）已经在后台启动好了。先确认它健康：

```bash
cd /root/workspace && curl -s http://localhost:4566/_ministack/health | jq .
```{{exec}}

现在用 `pulumi config` 命令在当前 `dev` Stack 上设置两个配置：

```bash
pulumi config set bucketPrefix demo
```{{exec}}

```bash
pulumi config set aws:region us-east-1
```{{exec}}

列出当前 Stack 的全部配置：

```bash
pulumi config
```{{exec}}

再看这些值最终落在哪个文件里：

```bash
cat Pulumi.dev.yaml
```{{exec}}

留意两条键的差别。`bucketPrefix` 没写命名空间，于是 Pulumi 自动用项目名作命名空间，存进文件后是 `pulumi-config:bucketPrefix`。而 `aws:region` 自带 `aws` 命名空间，原样保留——这正是命名空间用来隔离不同包 / 项目同名键的机制。

单独读取某个键：

```bash
pulumi config get bucketPrefix
```{{exec}}

这份 `Pulumi.dev.yaml` 应当提交到版本控制：它和程序一起，构成「这套基础设施在 dev 环境下的完整定义」。
