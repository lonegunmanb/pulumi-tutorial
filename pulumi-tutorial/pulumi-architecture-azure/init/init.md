# Pulumi 架构解析：Azure / miniblue 版

本实验使用 `ghcr.io/lonegunmanb/miniblue:sha-6d934ae` 在本地模拟 Azure。由于官方 `pulumi-azure-native` Provider 通常面向真实 Azure 认证与端点，本实验使用 Pulumi Dynamic Provider 直接调用 miniblue REST API。

这样可以更直观地看到：Provider 的本质就是把 Engine 的资源操作转换成目标平台 API 调用。

> 关于口令提示：本实验使用空口令的本地后端。第一次运行 `pulumi` 命令时，终端可能会提示 `Enter your passphrase to unlock config/secrets`——这是因为终端在环境准备脚本写入 `PULUMI_CONFIG_PASSPHRASE` 之前就打开了。直接按回车（空口令）即可继续，连续两次提示也都按回车。亲自体验一次这个“按回车打断”的过程，有助于理解 Pulumi 的口令机制。