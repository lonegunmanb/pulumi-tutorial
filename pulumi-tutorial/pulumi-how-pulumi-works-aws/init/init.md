# Pulumi 是如何工作的：AWS / MiniStack 版

本实验使用 MiniStack 在本地模拟 AWS S3。你会从一段 TypeScript 程序出发，观察 Pulumi 如何把资源声明转成注册请求，再由 Engine、State 与 AWS Provider 协作完成创建、更新和删除。

实验不需要真实 AWS 账号，所有资源都创建在本地容器中。

> 关于口令提示：本实验使用空口令的本地后端。第一次运行 `pulumi` 命令时，如果终端提示输入 passphrase，直接按回车即可继续。