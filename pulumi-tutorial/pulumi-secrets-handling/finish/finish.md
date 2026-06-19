# 实验完成

你已经把 Pulumi 的机密处理完整跑了一遍：

- **Secret 配置**：`pulumi config set --secret` 加密存储，CLI 输出与 `stack output` 自动遮蔽为 `[secret]`，`--show-secrets` 才显示明文；
- **程序内创建 secret**：`pulumi.secret()`、`config.requireSecret()` 与 `RandomPassword.result`（默认机密），且机密性经 `apply` 自动传播；
- **additionalSecretOutputs 与 ID 陷阱**：`RandomString` 的 `result` 同时是 `id`，明文泄漏；`RandomPassword` 把机密放在普通输出，才能真正加密；
- **只写字段（write-only）**：`secretStringWo` 只进 inputs、outputs 永远为 `null`，靠递增 `secretStringWoVersion` 触发更新；
- **加密 provider**：本地后端默认用 passphrase provider，`encryptionsalt` 与 `secure:` 密文都可安全提交 Git，生产可换成 KMS / Key Vault 等。

清理资源（可选）：

```bash
cd /root/workspace && \
pulumi destroy --yes && \
docker compose down
```{{exec}}

回到[「Secrets 机密处理」章节](https://killercoda.com/pulumi-tutorial)继续阅读生产检查清单。
