# Pulumi 架构解析：AWS / MiniStack 版

本实验使用 MiniStack 在本地模拟 AWS S3。你会看到：

- Pulumi 程序如何表达“期望状态”。
- `pulumi preview` 如何计算将要发生的资源操作。
- AWS Provider 如何把 Engine 的指令转成 S3 API 调用。
- State 如何记录资源 URN、类型和输出。

实验不需要真实 AWS 账号，所有资源都创建在本地 MiniStack 容器中。

> 关于口令提示：本实验使用空口令的本地后端。第一次运行 `pulumi` 命令时，终端可能会提示 `Enter your passphrase to unlock config/secrets`——这是因为终端在环境准备脚本写入 `PULUMI_CONFIG_PASSPHRASE` 之前就打开了。直接按回车（空口令）即可继续，连续两次提示也都按回车。亲自体验一次这个“按回车打断”的过程，有助于理解 Pulumi 的口令机制。