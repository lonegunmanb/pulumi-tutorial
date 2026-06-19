# 加密 provider 与 encryptionsalt

最后看「谁来保管那把加密密钥」——也就是 **secret 加密 provider**。本实验用的是本地后端（`pulumi login --local`），它默认采用 **passphrase** provider：用一个口令（这里是空口令）派生出加密密钥。

打开 stack 配置文件，看两样东西：

```bash
cd /root/workspace && \
cat Pulumi.dev.yaml
```{{exec}}

你会看到：

- `encryptionsalt: v1:...` —— passphrase provider 的盐值，密钥就是用它配合口令派生出来的；
- 前面 `pulumi config set --secret` 设置的 `dbPassword` / `apiKey`，都是 `secure:` 开头的密文。

这两样**都可以、也推荐安全地提交进 Git**：没有口令（或没有对应加密 provider 的访问权限），任何人都解不开这些密文，于是代码与配置就能一起做版本管理。

如果配置文件丢了或想重建，可用最近一次部署的配置还原它：

```bash
pulumi config refresh && \
cat Pulumi.dev.yaml
```{{exec}}

**生产环境如何选 provider？** 在 `pulumi stack init` 时用 `--secrets-provider` 指定即可，例如换成 AWS KMS：

```text
pulumi stack init prod \
  --secrets-provider="awskms://alias/my-key?region=us-east-1"
```

可选的 provider 有 `default`（Pulumi Cloud 托管）、`passphrase`（本实验所用）、`awskms`、`azurekeyvault`、`gcpkms`、`hashivault`。对**已存在**的 stack，则用 `pulumi stack change-secrets-provider "<provider>"` 把现有 secret 重新加密成新 provider 的形式——换完后 `pulumi preview` 应当看不到任何待变更。

> 上面的 KMS / change-secrets-provider 命令需要真实云凭据，本地 LocalStack 环境无法演示，这里只作了解。本实验的重点是：**机密在磁盘上始终是密文，密钥的保管方可按需替换。**
