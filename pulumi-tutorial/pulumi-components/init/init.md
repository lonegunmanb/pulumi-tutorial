# ComponentResource 组件化（AWS / MiniStack）

本实验用真实的 `@pulumi/aws` provider 对接本地的 **MiniStack**（AWS 模拟器），全程无需任何云账号或凭据。

你将从一段「平铺」的资源声明出发，把它封装成一个 `SecureBucket` 组件，观察：

- 子资源如何挂到组件名下，URN 如何体现父子关系；
- `registerOutputs()` 注册的输出如何出现在 stack output 里；
- 给组件传 `providers` 如何下传到每个子资源；
- 在组件内部给子资源改名会触发替换，以及如何用 `aliases` 零重建修复。

环境正在后台准备（安装 Pulumi、Node.js，并拉起 MiniStack 容器），请稍候。
