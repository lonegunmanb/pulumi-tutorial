# 完成

你已经完成 Azure 版 Stack 详解实验。

这次你练习了：

- 创建、列出、选择 Stack。
- 区分 active stack 对 `config`、`preview`、`up`、`destroy` 的影响。
- 对比 `Pulumi.dev.yaml` 与 `Pulumi.prod.yaml`。
- 使用 `pulumi.get_stack()` 让同一份代码按环境生成不同资源名。
- 查看 Stack Outputs 与 JSON 输出。
- 导出 State 并理解它为什么需要谨慎处理。
- 亲眼看到“资源名依赖 Stack 名”的 Stack 改名会改写资源（模拟环境是 update，真实云通常是 replace）。
- 对比空 Stack 的 rename 与 rm 有多安全。

下一章进入资源模型，你会进一步学习 Pulumi 如何追踪资源身份、依赖关系与安全重构。