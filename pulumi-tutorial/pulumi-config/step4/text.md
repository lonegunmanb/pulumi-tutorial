# 机密配置：--secret 的加密与遮蔽

有些配置是敏感数据——数据库密码、API Token。用 `--secret` 设置，它就会被加密：

```bash
pulumi config set --secret dbPassword 'S3cr3t-Pa55!'
```{{exec}}

看它在配置文件里长什么样：

```bash
cat Pulumi.dev.yaml
```{{exec}}

`dbPassword` 不再是明文，而是一段 `secure:` 开头的密文。因为已加密，这份文件可以放心提交到 Git。

切换到读取机密配置的程序：

```bash
cp variants/step4.ts index.ts && cat index.ts
```{{exec}}

程序里用 `config.requireSecret("dbPassword")` 读取。它返回的不是普通字符串，而是一个携带「机密性」的 `Output`——这个机密属性会一路传播，序列化进 state 时被加密，打印进输出时被遮蔽。

部署，再看导出的机密值默认是被遮蔽的：

```bash
pulumi up --yes && pulumi stack output
```{{exec}}

`dbPasswordOut` 显示为 `[secret]`。只有显式要求时才会明文显示：

```bash
pulumi stack output dbPasswordOut --show-secrets
```{{exec}}

机密配置只是配置的一个子集；它与 Output、state 加密、加密 provider 的完整机制，留到「Secrets 机密处理」一章细讲。
