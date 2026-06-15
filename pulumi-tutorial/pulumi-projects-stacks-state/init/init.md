# Projects、Stacks 与 State（AWS / MiniStack）

本实验使用本地 Pulumi 后端和 MiniStack 模拟 AWS S3。你会操作两个 Pulumi Project：

- `/root/workspace/aws-infra`：上游 Project，创建模拟 S3 Bucket，演示 Stack、Config、Secret、Output 与 State。
- `/root/workspace/aws-consumer`：下游 Project，通过 `StackReference` 读取上游 Stack 的输出。

全程不需要 AWS 账号，也不需要登录 Pulumi 官方服务。