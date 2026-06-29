# 使用 Terraform Module（Azure / MiniBlue）

本实验会在本地启动 MiniBlue，并用 Pulumi 的 Terraform Module provider 引入 `Azure/avm-res-network-virtualnetwork/azurerm`。

你会先观察一个预创建的 Resource Group，再通过 AVM 模块创建 Virtual Network 和 Subnet，最后修改模块输入让 VNet 增加一个子网。

环境正在后台准备，请稍候。