# 完成

你已经用 Pulumi 调用了 `Azure/avm-res-network-virtualnetwork/azurerm`，并把 VNet 与子网创建到了 MiniBlue。

本实验展示了：

- Terraform Module 可以通过 package 生成进入 Pulumi TypeScript 项目。
- 模块可以接收已有 Resource Group 的资源 ID 作为 parent_id。
- 模块输出可以直接作为 Pulumi Stack 输出读取。
- 修改 subnets 输入后，Pulumi preview 会显示模块内部资源变化。

AWS 与 Azure 两个实验使用的是同一套机制：Pulumi 管外层 Stack，Terraform Module provider 执行模块内部资源图。