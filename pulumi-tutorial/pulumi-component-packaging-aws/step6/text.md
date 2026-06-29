# 安装 executable-based plugin

最后看第三条路径：executable-based plugin package。它不是普通 npm 包，也不是 source-based package，而是把组件实现放进 `pulumi-resource-*` 可执行文件，再让消费者从这个本地路径生成 SDK。

本实验用 Go 和 `pulumi-go-provider` 写了一个 `SecureBucket` 组件 provider。它和前两条路径一样创建主桶与日志桶，只是组件通过本地可执行插件分发。

Killercoda 环境的 CPU、内存和网络都比较受限，现场编译带 AWS Go SDK 的 provider 会非常慢。因此本实验把 Linux amd64 插件归档预先放在 assets 中，进入环境时解压到 provider 目录。归档保留了二进制的执行权限，所以不需要再执行 chmod。

查看本地 component provider 的代码：

```bash
sed -n '1,280p' /root/repos/aws-secure-exec-provider/main.go
```{{exec}}

确认预编译 provider 插件已经就绪，并把它安装进 Pulumi 本地插件缓存。注意解压后的文件名必须符合 `pulumi-resource-<package-name>` 约定：

```bash
tar -tzf /root/pulumi-resource-aws-secure-exec-v0.1.0-linux-amd64.tar.gz && \
ls -l /root/repos/aws-secure-exec-provider/bin/pulumi-resource-aws-secure-exec && \
pulumi plugin install resource aws-secure-exec 0.1.0 --file /root/repos/aws-secure-exec-provider/bin/pulumi-resource-aws-secure-exec --reinstall
```{{exec}}

`pulumi package add` 会从本地二进制生成 SDK，但部署时仍需要 Pulumi 能在本地插件缓存中找到同名同版本的 resource plugin，所以这里显式执行一次 plugin install。归档中的可执行位会在解压时保留。

用 Pulumi 读取这个可执行插件暴露的 schema：

```bash
pulumi package get-schema /root/repos/aws-secure-exec-provider/bin/pulumi-resource-aws-secure-exec | jq '.name, (.resources | keys)'
```{{exec}}

进入第三个消费者项目，从本地可执行插件路径添加 package：

```bash
cd /root/workspace/exec-consumer && \
pulumi package add /root/repos/aws-secure-exec-provider/bin/pulumi-resource-aws-secure-exec && \
npm install --no-audit --no-fund
```{{exec}}

确认本地 SDK 已经生成，并查看消费者程序：

```bash
cd /root/workspace/exec-consumer && \
node -p "require('./package.json').dependencies['aws-secure-exec']" && \
find sdks -maxdepth 3 -type f | sort | head -30 && \
sed -n '1,120p' index.ts
```{{exec}}

部署这个 executable-based 组件：

```bash
cd /root/workspace/exec-consumer && \
pulumi up --yes
```{{exec}}

读取输出并清理三个消费者项目：

```bash
cd /root/workspace/exec-consumer && \
pulumi stack output && \
pulumi destroy --yes && \
cd /root/workspace/source-consumer && \
pulumi destroy --yes && \
cd /root/workspace/native-consumer && \
pulumi destroy --yes
```{{exec}}

到这里，三条路径的差异就完整串起来了：native package 直接走语言包管理器，source-based package 从源代码生成 SDK，executable-based package 则从本地可执行插件提取 schema 并生成 SDK。