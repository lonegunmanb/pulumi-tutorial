# 用 pulumi package add 消费

进入另一个消费者项目，从 Git tag 添加 source-based package：

```bash
cd /root/workspace/source-consumer && \
pulumi package add file:///root/repos/azure-secure-storage-source.git@v0.1.0 && \
npm install --no-audit --no-fund
```{{exec}}

命令会生成本地 SDK，并把依赖写入消费者项目。看一下生成结果：

```bash
cd /root/workspace/source-consumer && \
node -p "require('./package.json').dependencies['azure-secure-storage']" && \
find sdks -maxdepth 3 -type f | sort | head -30
```{{exec}}

现在看消费者程序。它导入的是 `pulumi package add` 生成的 SDK：

```bash
sed -n '1,240p' /root/workspace/source-consumer/index.ts
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