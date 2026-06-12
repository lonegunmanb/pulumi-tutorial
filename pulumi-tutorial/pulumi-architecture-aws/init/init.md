# Pulumi 架构解析：AWS / MiniStack 版

本实验使用 MiniStack 在本地模拟 AWS S3。你会看到：

- Pulumi 程序如何表达“期望状态”。
- `pulumi preview` 如何计算将要发生的资源操作。
- AWS Provider 如何把 Engine 的指令转成 S3 API 调用。
- State 如何记录资源 URN、类型和输出。

实验不需要真实 AWS 账号，所有资源都创建在本地 MiniStack 容器中。