# Projects、Stacks 与 State（Azure / miniblue）

本实验使用本地 Pulumi 后端和 `ghcr.io/lonegunmanb/miniblue:sha-6d934ae` 模拟 Azure 风格资源。你会操作两个 Pulumi Project：

- `/root/workspace/azure-infra`：上游 Project，通过 Python Dynamic Provider 调用 miniblue，创建 Resource Group 与 Key Vault Secret。
- `/root/workspace/azure-consumer`：下游 Project，通过 `StackReference` 读取上游 Stack 的输出。

全程不需要 Azure 账号，也不需要登录 Pulumi 官方服务。