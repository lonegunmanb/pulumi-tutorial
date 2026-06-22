# State 与 Backend（Azure / miniblue）

本实验使用 miniblue 提供本地 Azure Blob 风格存储，不需要真实 Azure 账号，也不需要 Pulumi Cloud 账号。

你将使用 /root/workspace/state-backends-azure 这个 Pulumi Project，完成这些练习：

- 登录 Azure Blob DIY Backend。
- 使用 AZURE_STORAGE 变量访问状态容器。
- 创建 dev 与 prod 两个 Stack。
- 观察 State 写入 Blob container 后的 .pulumi 目录结构。
- 导出并重新导入 Stack State。

点击右侧箭头开始第一步。
