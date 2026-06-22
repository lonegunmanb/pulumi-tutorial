# 部署 prod 的多子网网络

现在切到 prod 做预览。这个环境会创建更多子网，并为私有数据子网创建 NSG：

```bash
cd /root/workspace && \
pulumi stack select prod && \
pulumi preview
```{{exec}}

确认计划符合配置矩阵后部署：

```bash
pulumi up --yes && \
pulumi stack output
```{{exec}}

查看 prod 的网络计划输出。它应该包含 app、services 和 data 三个子网：

```bash
pulumi stack output networkPlan | jq
```{{exec}}

对比两个 Stack 的子网输出。这里对比的是程序导出的计划子网名，不依赖模拟器回填的 VNet 子网字段：

```bash
echo '--- dev ---' && pulumi stack output --stack dev subnetNames | jq && \
echo '--- prod ---' && pulumi stack output --stack prod subnetNames | jq
```{{exec}}

再看 prod 的私有 NSG 名称：

```bash
pulumi stack output privateNetworkSecurityGroup --stack prod
```{{exec}}
