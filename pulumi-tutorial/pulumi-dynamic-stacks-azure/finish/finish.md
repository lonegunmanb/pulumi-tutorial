# 完成

你已经完成 Azure 版动态 Stack 配置实验。

这次你练习了：

- 读取 dev/prod 两份网络配置矩阵。
- 用同一套程序按配置创建 Resource Group、Virtual Network 和 Subnet。
- 用配置开关条件创建私有子网 NSG。
- 用 Secret 配置派生输出，并观察输出遮蔽。
- 用 Output 连接 Resource Group、VNet、Subnet 和 NSG 的依赖。
- 用 refresh 识别手工标签漂移，再用 preview 和 up 恢复。
- 在高风险网络改动前备份 Stack 配置和 State，并恢复配置。

## 清理

销毁两个 Stack 的资源并停掉 miniblue：

```bash
cd /root/workspace && \
pulumi destroy --yes --stack prod && \
pulumi destroy --yes --stack dev && \
docker compose down
```{{exec}}

## 延伸阅读

- 教程正文：多环境 Stack 配置与动态基础设施。
- 官方文档：<https://www.pulumi.com/docs/iac/concepts/config/>
- 漂移检测命令：<https://www.pulumi.com/docs/iac/cli/commands/pulumi_refresh/>
