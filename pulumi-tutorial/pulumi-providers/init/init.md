# Provider 抽象：从 default 到 dynamic

本实验是一个**纯本地、零云依赖**的 TypeScript 项目，不需要任何云账号或凭据。你会用三步走完 provider 抽象的三种形态：

1. **default vs explicit provider**：用 `@pulumi/random` 对比两种用法。
2. **Any Terraform Provider**：用 `pulumi package add` 把一个没有官方 Pulumi 包的 Terraform provider 拉进来，创建本地文件。
3. **Dynamic Provider**：亲手实现 `create`/`update`/`delete`，观察引擎调用 CRUD 的时机。

> 所有程序变体已预先写入 `/root/workspace/variants/`，每一步只需拷贝对应文件到 `index.ts` 再跑 `pulumi`。你也可以在编辑器里打开这些文件对照阅读。

> `hashicorp/local` 这个 Terraform provider 的本地 SDK 已在初始化阶段预先生成（`pulumi package add terraform-provider hashicorp/local`），第 2 步可直接使用。

> 关于口令提示：本实验使用空口令的本地后端。第一次运行 `pulumi` 命令时，终端可能提示 `Enter your passphrase`——直接按回车（空口令）即可。
