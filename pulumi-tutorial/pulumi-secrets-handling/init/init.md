# Secrets 机密处理（AWS / LocalStack）

本实验用 `pulumi/pulumi-aws`（`@pulumi/aws`）对接本地 **LocalStack** 模拟器，全程不需要真实 AWS 账号。你会把第 7 章的机密处理概念逐一跑通：

- 用 `pulumi config set --secret` 设置机密配置，观察 CLI 遮蔽与 `Pulumi.dev.yaml` 里的 `secure:` 密文；
- 在程序里用 `requireSecret` / `pulumi.secret()` 创建 secret，并通过 `pulumi stack export` 验证 state 中的加密；
- 用 `additionalSecretOutputs` 标记输出，复现「资源 ID 无法加密」的陷阱（`RandomString` vs `RandomPassword`）；
- 用 `aws.secretsmanager.SecretVersion` 的 `secretStringWo` / `secretStringWoVersion` 演示只写字段；
- 观察本地后端的 `passphrase` 加密 provider 与 `encryptionsalt`，并用 `pulumi config refresh` 重建配置。

> 多个程序变体已预先写入 `/root/workspace/variants/`，每一步只需把对应文件拷贝到 `index.ts` 再运行 `pulumi`。你也可以在左侧编辑器里打开这些文件对照阅读。

> 关于口令提示：本实验使用空口令的本地后端（passphrase provider）。第一次运行 `pulumi` 命令时，终端可能提示 `Enter your passphrase`——直接按回车（空口令）即可。
