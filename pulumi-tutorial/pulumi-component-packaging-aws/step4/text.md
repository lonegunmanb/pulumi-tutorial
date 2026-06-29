# 用 pulumi package add 消费

进入另一个消费者项目。因为 Killercoda 实验使用的是本地 Git 仓库，我们先把组件仓库工作树切到 `v0.1.0`，再用本地目录路径添加 source-based package：

```bash
git -C /root/repos/aws-secure-bucket-source-work checkout --detach v0.1.0 && \
cd /root/workspace/source-consumer && \
pulumi package add /root/repos/aws-secure-bucket-source-work && \
npm install --no-audit --no-fund
```{{exec}}

真实远端仓库中可以直接写 Git URL 加 tag；本地路径方式则依赖当前工作树已经检出到目标版本。用本地路径生成 Node SDK 时，依赖名会带 `@pulumi/` scope。命令会生成本地 SDK，并把依赖写入消费者项目。看一下生成结果：

```bash
cd /root/workspace/source-consumer && \
node -p "require('./package.json').dependencies['@pulumi/aws-secure-bucket']" && \
find sdks -maxdepth 3 -type f | sort | head -30
```{{exec}}

现在看消费者程序。它导入的是 `pulumi package add` 生成的 SDK：

```bash
sed -n '1,220p' /root/workspace/source-consumer/index.ts
```{{exec}}

部署 source-based package 版本：

```bash
cd /root/workspace/source-consumer && \
pulumi up --yes
```{{exec}}

读取输出：

```bash
cd /root/workspace/source-consumer && \
pulumi stack output
```{{exec}}

这条路径多了 SDK 生成步骤，但消费者可以是 Pulumi 支持的其他语言项目。