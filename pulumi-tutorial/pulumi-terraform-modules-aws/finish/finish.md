# 完成

你已经用 Pulumi 调用了 `terraform-aws-modules/vpc/aws`，并把真实资源创建到了 MiniStack。

本实验串起了几件事：

- `pulumi package add terraform-module` 会把 Terraform Module 变成当前语言可导入的本地 SDK。
- 模块 package 的 provider 配置可以把 Terraform provider 调用指向本地模拟器。
- 模块输出会成为 Pulumi Stack 输出，可以继续被其他资源消费。
- 修改模块输入后，Pulumi 仍然负责预览和更新，模块内部资源图由 OpenTofu 执行。

下一步可以继续完成 Azure / MiniBlue 版本，对比 Azure AVM 模块在同一机制下的使用方式。