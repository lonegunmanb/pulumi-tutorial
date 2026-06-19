# 完成

你已经用 `@pulumi/azure`（azurerm）+ miniblue 走完了资源命名与精细控制的完整闭环：

- 看清了一个资源的 logical name、physical name、physical ID（ARM resource ID）与 URN。
- 用 `replaceOnChanges` 制造了一次 replace，并用 `deleteBeforeReplace` 避免了固定物理名的冲突。
- 区分了隐式依赖与显式 `dependsOn`。
- 用 `aliases` 完成了零重建重命名。
- 用 `protect` 拦截了误删，用 `ignoreChanges` 忽略了 tag 漂移。
- 用 `transforms` 给忘记关联 NSG 的子网自动补上了默认 NSG。

这套概念与 AWS / MiniStack 版完全对应——资源身份与资源选项是 Pulumi 引擎层面的能力，与具体 provider 无关。下一章进入 Components，你会把这些资源封装成可复用的高层抽象。
