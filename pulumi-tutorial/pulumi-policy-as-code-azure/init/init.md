# Policy as Code（Azure / miniblue）

本实验使用 miniblue 提供本地 Azure 风格 API，不需要真实 Azure 账号，也不需要 Pulumi Cloud 账号。

你将操作 /root/workspace/policy-as-code-azure 下的两个目录：

- app：一个声明 Resource Group 的 Pulumi Project。
- policy-pack：一个本地 TypeScript Policy Pack。

你会先看到不合规 Resource Group 可以通过普通 preview，然后用本地策略包阻断它，最后修复资源并带策略完成更新。