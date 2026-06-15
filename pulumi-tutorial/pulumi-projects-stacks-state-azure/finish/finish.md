# 完成

你已经完成 Azure / miniblue 版实验：

- 用一个 `azure-infra` Project 创建 `dev` 与 `prod` 两个 Stack。
- 为不同 Stack 设置独立 Config 与 Secret。
- 通过 Stack Outputs 读取模拟 Resource Group、Key Vault 和交接信息。
- 导出本地 State 并观察 URN、资源类型和 Outputs。
- 用 `azure-consumer` Project 通过 `StackReference` 读取上游输出。

现在你已经在 AWS 风格和 Azure 风格两个模型中练习了同一组 Pulumi 基础概念。后续章节会在这个基础上继续讲资源依赖、生命周期选项和组件化封装。