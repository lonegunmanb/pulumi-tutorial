# 消费 native package

Native package 是普通 npm 包。它没有 `PulumiPlugin.yaml`，消费者也不会运行 Pulumi package add。

查看这个包暴露的入口文件：

```bash
sed -n '1,180p' /root/repos/aws-secure-bucket-native-work/dist/index.js
```{{exec}}

进入消费者项目，并从 Git tag 安装这个 npm 包：

```bash
cd /root/workspace/native-consumer && \
npm install git+file:///root/repos/aws-secure-bucket-native.git#v0.1.0 --no-audit --no-fund
```{{exec}}

确认依赖已经记录为 Git 版本：

```bash
cd /root/workspace/native-consumer && \
node -p "require('./package.json').dependencies['aws-secure-bucket-native']"
```{{exec}}

现在看消费者程序。它直接从 npm 包导入组件类：

```bash
sed -n '1,220p' /root/workspace/native-consumer/index.ts
```{{exec}}

执行部署。这里所有 AWS 调用都会被显式 provider 指向本地 MiniStack：

```bash
cd /root/workspace/native-consumer && \
pulumi up --yes
```{{exec}}

读取输出，确认组件暴露的值可以像普通资源输出一样使用：

```bash
cd /root/workspace/native-consumer && \
pulumi stack output
```{{exec}}

这条路径简单，但只能被 TypeScript 或 JavaScript 项目使用。下一步切换到 source-based plugin package。