# 最佳实践（AWS / MiniStack RDS）

本实验用真实的 `@pulumi/aws` provider 对接本地 MiniStack。MiniStack 会模拟 AWS RDS 控制面，并在创建 RDS 实例时启动本地 PostgreSQL 容器，全程无需真实 AWS 账号。

你会操作三个目录：

- `/root/workspace/best-practices-aws/platform`：平台 Project，创建共享 PostgreSQL 参数组。
- `/root/workspace/best-practices-aws/workload`：工作负载 Project，通过组件创建数据库。
- `/root/workspace/best-practices-aws/policy-pack`：本地策略包，在 preview 阶段检查最终资源。

本实验会覆盖共享基础设施、组件安全默认值、Stack 配置、Secret、受限输入、StackReference 和本地 Policy Pack。

环境正在后台准备（安装 Pulumi、Node.js，安装依赖，并启动 MiniStack RDS），请稍候。