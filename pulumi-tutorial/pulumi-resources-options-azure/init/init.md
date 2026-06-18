# 资源与精细控制：Azure / miniblue 版

本实验用 `pulumi/pulumi-azure`（`@pulumi/azure`，即 azurerm 经典 provider）对接本地 **miniblue** 模拟器，全程不需要真实 Azure 订阅。你会用一组 Resource Group 依次体验：

- 资源的四种身份：logical name、physical name、physical ID（ARM resource ID）、URN。
- auto-naming、显式物理名与 `replaceOnChanges` + `deleteBeforeReplace`。
- 隐式依赖与显式 `dependsOn`。
- 用 `aliases` 完成零重建重命名。
- `protect` 拦截误删、`ignoreChanges` 忽略漂移。

> 所有程序变体已预先写入 `/root/workspace/variants/`，每一步只需拷贝对应文件到 `index.ts` 再跑 `pulumi`。你也可以在编辑器里打开这些文件对照阅读。

> miniblue 通过 4567 端口提供 HTTPS metadata 服务，azurerm provider 需要信任它的证书。**第 1 步**会在启动容器后导出并信任该证书，之后才能 `pulumi up`。

> 关于口令提示：本实验使用空口令的本地后端。第一次运行 `pulumi` 命令时，终端可能提示 `Enter your passphrase`——直接按回车（空口令）即可。
