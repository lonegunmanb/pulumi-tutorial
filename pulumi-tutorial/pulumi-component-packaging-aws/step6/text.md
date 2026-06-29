# 编译 executable-based plugin

最后看第三条路径：executable-based plugin package。它不是普通 npm 包，也不是 source-based package，而是先把 provider 编译成 `pulumi-resource-*` 可执行文件，再让消费者从这个本地路径生成 SDK。

本实验用 Go 和 `pulumi-go-provider` 写了一个 `SecureBucket` 组件 provider。它和前两条路径一样创建主桶与日志桶，只是组件通过本地可执行插件分发。

先确认 Go 工具链可用。`pulumi-go-provider v1.3.2` 需要较新的 Go 工具链，所以这条命令会原地补装 Go 1.25.x：

```bash
if ! /usr/local/go/bin/go version 2>/dev/null | grep -q 'go1.25.'; then cd /tmp && curl -fsSLO https://go.dev/dl/go1.25.11.linux-amd64.tar.gz && rm -rf /usr/local/go && tar -C /usr/local -xzf go1.25.11.linux-amd64.tar.gz; fi && \
export PATH=/usr/local/go/bin:$PATH && \
export GOFLAGS=-mod=mod && \
go version
```{{exec}}

查看本地 component provider 的代码：

```bash
sed -n '1,280p' /root/repos/aws-secure-exec-provider/main.go
```{{exec}}

编译本地 provider 插件，并把它安装进 Pulumi 本地插件缓存。注意输出文件名必须符合 `pulumi-resource-<package-name>` 约定：

```bash
cd /root/repos/aws-secure-exec-provider && \
export PATH=/usr/local/go/bin:$PATH && \
export GOFLAGS=-mod=mod && \
go mod tidy && \
go build -o bin/pulumi-resource-aws-secure-exec . && \
pulumi plugin install resource aws-secure-exec 0.1.0 --file /root/repos/aws-secure-exec-provider/bin/pulumi-resource-aws-secure-exec --reinstall
```{{exec}}

`pulumi package add` 会从本地二进制生成 SDK，但部署时仍需要 Pulumi 能在本地插件缓存中找到同名同版本的 resource plugin，所以这里显式执行一次 plugin install。

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