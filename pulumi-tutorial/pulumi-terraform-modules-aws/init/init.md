# 使用 Terraform Module（AWS / MiniStack）

本实验会在本地启动 MiniStack，并用 Pulumi 的 Terraform Module provider 引入 `terraform-aws-modules/vpc/aws`。

你会看到一个 Terraform Registry 模块如何被加入 Pulumi 项目、如何生成本地 SDK、如何通过模块 package 的 provider 指向 MiniStack，以及模块输出如何回到 Pulumi Stack 输出中。

环境正在后台准备，请稍候。