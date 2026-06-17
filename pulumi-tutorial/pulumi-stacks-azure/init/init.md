# Stack 详解（Azure / miniblue）

本实验只使用本地环境，不需要 Azure 账号，也不需要登录 Pulumi Cloud。

你会使用 `/root/workspace/azure-stacks` 这个 Pulumi Project，配合 `miniblue` 模拟 Azure 风格资源，完成这些练习：

- 创建并切换 `dev` / `prod` Stack。
- 观察 active stack 如何影响 `config`、`preview`、`up`、`destroy`。
- 查看 `Pulumi.dev.yaml` 与 `Pulumi.prod.yaml` 的差异。
- 使用 `pulumi.get_stack()` 生成不同环境的资源名。
- 查看 Stack Outputs、导出 State，并安全演示空 Stack 的 rename / rm。