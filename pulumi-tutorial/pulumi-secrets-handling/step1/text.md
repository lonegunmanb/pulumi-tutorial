# Secret 配置与遮蔽

初始程序（`variants/step1.ts` 已拷贝为 `index.ts`）会读取两个配置：明文的 `region` 和机密的 `dbPassword`，并把后者拼进一条连接串。

先看一眼程序：

```bash
cat /root/workspace/index.ts
```{{exec}}

现在用 `--secret` 设置机密配置。注意 CLI 会**加密**它，存的是密文：

```bash
cd /root/workspace && \
pulumi config set --secret dbPassword 'S3cr37-P@ss'
```{{exec}}

列出配置——机密值不会以明文打印，而是显示为 `[secret]`：

```bash
pulumi config
```{{exec}}

部署。即便程序导出了 `dbPassword` 和由它派生的连接串，输出里它们也都被**遮蔽**成 `[secret]`：

```bash
pulumi up --yes && \
pulumi stack output
```{{exec}}

`regionOut` 是明文，正常显示；`exportedPassword` 和 `connectionStringOut` 都是 `[secret]`——后者本是普通字符串拼接的结果，因为原料里有 secret，**机密性自动传播**了过来。

要查看被遮蔽的真实值，可显式加 `--show-secrets`：

```bash
pulumi stack output --show-secrets
```{{exec}}

最后打开 stack 配置文件，看机密在磁盘上的样子——`dbPassword` 是一段 `secure:` 密文，可以安全地提交进 Git：

```bash
grep -A2 'dbPassword\|secure' Pulumi.dev.yaml
```{{exec}}

> 如果某个值被 Pulumi 误判为机密而中止命令，可改用 `pulumi config set --plaintext <key> <value>` 显式声明它是明文。
