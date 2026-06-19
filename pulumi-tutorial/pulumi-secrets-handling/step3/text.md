# additionalSecretOutputs 与资源 ID 陷阱

有些资源属性默认不是 secret，需要你用 `additionalSecretOutputs` 资源选项显式标记。但这里藏着一个**生产级陷阱**：资源的 physical ID 永远以明文进 state，无法加密。

切换到 step3 变体：

```bash
cd /root/workspace && \
cp variants/step3.ts index.ts && \
cat index.ts
```{{exec}}

程序里建了两个资源，都用 `additionalSecretOutputs: ["result"]` 把 `result` 标成 secret：

- `RandomString`：它的 `result` **同时也是它的 id**；
- `RandomPassword`：它的 `result` 不是 id。

部署：

```bash
pulumi up --yes && \
pulumi stack output
```{{exec}}

`insecureResult` 和 `secureResult` 在输出里都是 `[secret]`，看起来都安全。但真相藏在 state 里。导出 state，对比两者：

```bash
pulumi stack export | jq '.deployment.resources[] | select(.type | test("random")) | {type, id, result: .outputs.result}'
```{{exec}}

仔细看：

- `RandomString` 的 `result` 是密文，**但它的 `id` 是明文**——而这个 id 恰好等于那个随机串，机密就这样泄漏了。把 `id` 加进 `additionalSecretOutputs` 也没用，因为 `id` 是特殊属性，不是普通输出。
- `RandomPassword` 的 `result` 是密文，且它的 `id` 不是那个密码——机密没有泄漏。

> 一句话记牢：**不要让敏感值出现在资源的 physical ID 里。** 选资源时，优先选把机密放在普通输出（如 `result`）而非 `id` 上的那一个。
