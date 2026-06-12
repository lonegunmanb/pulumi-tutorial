# Pulumi 架构解析：Azure / miniblue 版

本实验使用 `ghcr.io/lonegunmanb/miniblue:sha-11ef0e8` 在本地模拟 Azure。由于官方 `pulumi-azure-native` Provider 通常面向真实 Azure 认证与端点，本实验使用 Pulumi Dynamic Provider 直接调用 miniblue REST API。

这样可以更直观地看到：Provider 的本质就是把 Engine 的资源操作转换成目标平台 API 调用。