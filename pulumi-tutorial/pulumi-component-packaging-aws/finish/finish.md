# 完成

你已经完成 AWS / MiniStack 版组件分发实验：

- 编写了一个 `SecureBucket` 组件；
- 把组件分别做成 native language package、source-based plugin package 与 executable-based plugin package；
- 用 Git tag 固定版本；
- 通过 npm、Git tag、本地可执行插件路径与 `pulumi package add` 消费组件；
- 部署后观察了组件资源树和输出。

对同语言团队，native package 是轻量起点。对多语言消费者，source-based package 更适合长期复用。