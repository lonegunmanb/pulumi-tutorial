# 动态 Stack 配置：Azure / miniblue 版

本实验使用本地 Pulumi 后端和 miniblue 模拟 Azure。你会用同一套 Pulumi 程序创建 Resource Group、Virtual Network 和 Subnet，并让 dev/prod 两份配置决定网络拓扑。

实验重点不是 Stack 生命周期操作，而是环境配置矩阵：location、地址空间、子网列表、私有子网开关、Secret、Outputs、preview、refresh 与变更前备份。

> 关于口令提示：本实验使用空口令的本地后端。第一次运行 Pulumi 命令时，如果终端提示输入 passphrase，直接按回车即可。
