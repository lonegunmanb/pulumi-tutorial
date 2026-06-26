# 最佳实践（Azure / miniblue DB for PostgreSQL）

本实验用真实的 `@pulumi/azure` provider 对接本地 miniblue。miniblue 会模拟 Azure Resource Manager 与 DB for PostgreSQL，全程无需真实 Azure 账号。

你会操作三个目录：

- `/root/workspace/best-practices-azure/platform`：平台 Project，创建共享 Resource Group。
- `/root/workspace/best-practices-azure/workload`：工作负载 Project，通过组件创建 PostgreSQL Flexible Server。
- `/root/workspace/best-practices-azure/policy-pack`：本地策略包，在 preview 阶段检查最终资源。

本实验会覆盖共享基础设施、组件安全默认值、Stack 配置、Secret、受限输入、StackReference 和本地 Policy Pack。

环境正在后台准备（安装 Pulumi、Node.js，安装依赖，并启动 miniblue），请稍候。