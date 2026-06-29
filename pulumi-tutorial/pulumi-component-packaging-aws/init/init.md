# Component 包分发与基于 Git 的版本化引用（AWS / MiniStack）

本实验使用 `@pulumi/aws` 对接本地 MiniStack，全程无需真实 AWS 账号。

你将看到组件的三种分发方式：native language package 通过 npm 从 Git tag 安装，source-based plugin package 通过 `pulumi package add` 从 Git tag 添加并生成 SDK，executable-based plugin package 则先编译成本地 `pulumi-resource-*` 可执行插件，再通过本地路径生成 SDK。

后台正在准备 Pulumi CLI、Node.js、MiniStack、本地 Git 仓库、Go provider 示例源码和三个消费者项目。准备完成后即可开始。

本实验覆盖三种分发方式，预计需要 15 到 20 分钟。executable-based 部分会使用 Go 编译一个很小的本地 provider 插件。