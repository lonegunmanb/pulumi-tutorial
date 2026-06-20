# Configuration 配置：AWS / MiniStack 版

本实验用 `pulumi/pulumi-aws`（`@pulumi/aws`）对接本地 **MiniStack** 模拟器，全程不需要真实 AWS 账号。你会用一组**由配置驱动**的 S3 Bucket 依次体验：

- 用 CLI 存取配置，看懂 Stack 配置文件 `Pulumi.dev.yaml` 与命名空间（aws:region 与项目级键的区别）。
- 在程序里用 Config 对象的 require / get 读取配置并驱动资源（含类型化 getter 与默认值）。
- 结构化配置：用 `--path` 设置对象 / 数组，再用 requireObject 读取。
- 机密配置：用 `--secret` 设值，观察它在 YAML 里加密、在输出里被遮蔽。
- 一套程序、dev 与 prod 两个 Stack，各自一份配置，产出不同基础设施。

> 所有程序变体已预先写入 `/root/workspace/variants/`，每一步只需把对应文件拷到 `index.ts` 再跑 `pulumi`。你也可以在编辑器里打开这些文件对照阅读。

> 关于口令提示：本实验使用空口令的本地后端。第一次运行 `pulumi` 命令时，终端可能提示 `Enter your passphrase`——直接按回车（空口令）即可。
