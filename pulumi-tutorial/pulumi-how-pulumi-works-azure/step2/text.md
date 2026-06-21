# 查看 State 与 Provider

先查看程序导出的 Stack output：

```bash
cd /root/workspace && pulumi stack output
```{{exec}}

这些输出来自资源创建后的真实结果。Resource Group 的物理名通常会带随机后缀，这是 Pulumi 的 auto-naming 在避免多环境命名冲突。

再从 State 中读取资源记录：

```bash
pulumi stack export | jq '.deployment.resources[] | select(.type=="azure:core/resourceGroup:ResourceGroup") | {urn, id, physicalName: .outputs.name, tags: .outputs.tags}'
```{{exec}}

这里能同时看到 URN、physical ID、physical name 和标签。Engine 下一次计算差异时，会拿新程序表达的期望状态与这些记录比较。

最后看本机已安装的 Pulumi 插件：

```bash
pulumi plugin ls
```{{exec}}

资源注册由语言宿主发给 Engine，真正调用 Azure API 的是 Azure resource plugin。插件通常缓存在本机的 Pulumi 插件目录中。

再验证显式 Provider 指向的是本地 metadata 服务：

```bash
pulumi stack export | jq '.deployment.resources[] | select(.type=="pulumi:providers:azure") | {urn, metadataHost: .inputs.metadataHost, registrationMode: .inputs.resourceProviderRegistrations}'
```{{exec}}

这里的 metadataHost 指向 localhost:4567，所以实验不会访问真实 Azure。