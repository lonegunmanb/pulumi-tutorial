# Pulumi 是如何工作的：Azure / miniblue 版

本实验使用 `ghcr.io/lonegunmanb/miniblue:sha-0e58f75` 在本地模拟 Azure，并通过 `@pulumi/azure` 管理 Resource Group。你会观察 Pulumi 如何把程序里的资源声明转成注册请求，再由 Engine、State 与 Azure Provider 协作完成创建、更新和删除。

实验不需要真实 Azure 账号，所有资源都创建在本地容器中。

> 关于口令提示：本实验使用空口令的本地后端。第一次运行 `pulumi` 命令时，如果终端提示输入 passphrase，直接按回车即可继续。