# 完成

你已经用 `@pulumi/aws` + MiniStack 走完了资源命名与精细控制的完整闭环：

- 看清了一个资源的 logical name、physical name、physical ID 与 URN。
- 用 `replaceOnChanges` 制造了一次 replace，并用 `deleteBeforeReplace` 避免固定物理名的冲突。
- 区分了隐式依赖与显式 `dependsOn`。
- 用 `aliases` 完成了零重建重命名。
- 用 `protect` 拦截了误删，用 `ignoreChanges` 忽略了 tag 漂移。

下一章进入 Components，你会用 `ComponentResource` 把这些资源封装成可复用的高层抽象。