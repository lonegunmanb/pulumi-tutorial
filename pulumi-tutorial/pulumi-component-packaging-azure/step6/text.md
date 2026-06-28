# 编译 executable-based plugin

最后看第三条路径：executable-based plugin package。它不是普通 npm 包，也不是 source-based package，而是先把 provider 编译成 `pulumi-resource-*` 可执行文件，再让消费者从这个本地路径生成 SDK。

本实验用 Go 和 `pulumi-go-provider` 写了一个很小的组件 provider。它只输出一个名称牌字符串，目的是把注意力放在插件边界、schema 和 SDK 生成流程上。

先确认 Go 工具链可用。如果后台初始化失败，这条命令也会原地补装 Go：

```bash
if ! /usr/local/go/bin/go version 2>/dev/null | grep -q 'go1.23.4'; then cd /tmp && curl -fsSLO https://go.dev/dl/go1.23.4.linux-amd64.tar.gz && rm -rf /usr/local/go && tar -C /usr/local -xzf go1.23.4.linux-amd64.tar.gz; fi && \
export PATH=/usr/local/go/bin:$PATH && \
export GOFLAGS=-mod=mod && \
go version
```{{exec}}

查看本地 component provider 的代码：

```bash
sed -n '1,260p' /root/repos/azure-secure-exec-provider/main.go
```{{exec}}

编译本地 provider 插件。注意输出文件名必须符合 `pulumi-resource-<package-name>` 约定：

```bash
cd /root/repos/azure-secure-exec-provider && \
export PATH=/usr/local/go/bin:$PATH && \
export GOFLAGS=-mod=mod && \
go mod tidy && \
go build -o bin/pulumi-resource-azure-secure-exec .
```{{exec}}

用 Pulumi 读取这个可执行插件暴露的 schema：

```bash
pulumi package get-schema /root/repos/azure-secure-exec-provider/bin/pulumi-resource-azure-secure-exec | jq '.name, (.resources | keys)'
```{{exec}}

进入第三个消费者项目，从本地可执行插件路径添加 package：

```bash
cd /root/workspace/exec-consumer && \
pulumi package add /root/repos/azure-secure-exec-provider/bin/pulumi-resource-azure-secure-exec
```{{exec}}

确认本地 SDK 已经生成，并查看消费者程序：

```bash
cd /root/workspace/exec-consumer && \
node -p "require('./package.json').dependencies['azure-secure-exec']" && \
find sdks -maxdepth 3 -type f | sort | head -30 && \
sed -n '1,140p' index.ts
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