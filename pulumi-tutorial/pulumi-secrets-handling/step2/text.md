# 程序内创建 Secret 与机密传播

除了从配置读取，程序里还能**主动创建** secret。切换到 step2 变体：

```bash
cd /root/workspace && \
cp variants/step2.ts index.ts && \
cat index.ts
```{{exec}}

这个程序演示三种「得到 secret」的方式：

- `pulumi.secret("...")` —— 把一个普通值显式包成 secret；
- `config.requireSecret("apiKey").apply(...)` —— 从配置读 secret 后 `apply` 派生，结果仍是 secret；
- `new random.RandomPassword(...)` —— 它的 `result` 输出被 random provider **默认标记为 secret**。

先设置 step2 需要的机密配置，然后部署：

```bash
pulumi config set --secret apiKey 'ak-live-0123456789' && \
pulumi up --yes && \
pulumi stack output
```{{exec}}

三个导出值——`wrappedValue`、`authHeaderOut`、`generatedPassword`——全部显示为 `[secret]`。

现在直接查看 **state 文件**里这些值的样子。被标记为 secret 的输出在 state 里是一段 `{"ciphertext": ...}` 密文，而非明文：

```bash
pulumi stack export | jq '.deployment.resources[] | select(.type=="pulumi:pulumi:Stack") | .outputs'
```{{exec}}

再看 `RandomPassword` 资源本身在 state 里的 `result`——同样是密文：

```bash
pulumi stack export | jq '.deployment.resources[] | select(.type=="random:index/randomPassword:RandomPassword") | .outputs.result'
```{{exec}}

> **重要警告**：`apply` / `all` 的回调内部拿到的是**解密后的明文**。Pulumi 能保证返回值继续是 secret，但拦不住你在回调里 `console.log(pw)` 把明文打印出去。回调内的明文值，要像对待真实密码一样谨慎。
