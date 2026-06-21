# 动态 Stack 配置：AWS / MiniStack 版

本实验使用本地 Pulumi 后端和 MiniStack 模拟 AWS S3。你会看到同一套 Pulumi 程序如何被 dev/prod 两份配置驱动出不同资源形态。

实验重点不是 Stack 生命周期操作，而是环境配置矩阵：Bucket 数量、访问日志开关、标签、Secret、Outputs、preview、refresh 与变更前备份。

> 关于口令提示：本实验使用空口令的本地后端。第一次运行 Pulumi 命令时，如果终端提示输入 passphrase，直接按回车即可。
