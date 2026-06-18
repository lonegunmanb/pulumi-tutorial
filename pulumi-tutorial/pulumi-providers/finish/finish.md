# 完成

你已经在一个纯本地项目里走完了 provider 抽象的三种形态：

- **default vs explicit provider**：理解了 default provider 的省事与 explicit provider（它本身是资源、配置可为 Output）的必要场景。
- **Any Terraform Provider**：用 `pulumi package add terraform-provider hashicorp/local` 把一个没有官方 Pulumi 包的 Terraform provider 拉进来，证明了「只要有 TF provider，就能在 Pulumi 里用」。
- **Dynamic Provider**：亲手实现 `create`/`update`/`delete`，看清了引擎在 `up` / 改属性 / `destroy` 时分别调用哪个方法——这正是 provider 进程在标准 provider 里替你做的事。

把这三步串起来，你应该能回答本章最核心的问题：**为什么 IaC 程序需要 provider 这层抽象**——因为它把「期望状态」翻译成「云 API 调用」，让你的程序保持声明式、多云统一、可组合。

下一章进入 Inputs、Outputs 与 Secrets，深入资源之间如何传递数据、如何处理异步与敏感值。
