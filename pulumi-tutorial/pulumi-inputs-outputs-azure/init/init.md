# Inputs 与 Outputs：数据流与依赖（Azure / miniblue）

本实验用 `pulumi/pulumi-azure`（`@pulumi/azure`）对接本地 **miniblue** 模拟器，全程不需要真实 Azure 账号。你会围绕一组 Resource Group，把第 6 章的 Input/Output 概念逐一跑通：

- Output 为什么不能当普通值用，必须用 `apply` 取真实值；
- 用 `apply` 变换单个 Output，结果仍是 Output；
- 把一个资源的 Output 当作另一个资源的 Input —— 依赖追踪与创建顺序；
- 用 `all` 组合多个 Output；
- 用 helpers（`interpolate` / `concat` / `jsonStringify`）简化拼字符串与生成 JSON。

> 所有程序变体已预先写入 `/root/workspace/variants/`，每一步只需把对应文件拷贝到 `index.ts` 再运行 `pulumi`。你也可以在左侧编辑器里打开这些文件对照阅读。

> 关于口令提示：本实验使用空口令的本地后端。第一次运行 `pulumi` 命令时，终端可能提示 `Enter your passphrase`——直接按回车（空口令）即可。
