# Write-only 只写字段

前面讲的 secret 都是「加密后写进 state、需要时再解密读回」。还有另一类字段——**只写字段（write-only）**：能写进去，但云 API 永远不会把它读回来，因此你**无法从 state 里取回它的真实值**。

本步用 AWS Secrets Manager 的 `aws.secretsmanager.SecretVersion` 演示，它的只写字段是 `secretStringWo`，配套版本字段是 `secretStringWoVersion`。需要 LocalStack，先启动它：

```bash
cd /root/workspace && \
docker compose up -d && \
curl -s http://localhost:4566/_localstack/health | jq . 2>/dev/null || echo "LocalStack 启动中，可稍等几秒再继续"
```{{exec}}

切换到 step4 初始变体并部署：

```bash
cp variants/step4-v1.ts index.ts && \
cat index.ts && \
pulumi up --yes
```{{exec}}

现在看 state。只写字段无论在 inputs 还是 outputs 里，都只会以**加密 secret 密文**的形式出现，**绝不会是明文**：

```bash
pulumi stack export | jq '.deployment.resources[] | select(.type=="aws:secretsmanager/secretVersion:SecretVersion") | {inputs_keys: (.inputs | keys), secretStringWo_in_inputs: .inputs.secretStringWo, secretStringWo_in_outputs: .outputs.secretStringWo, hasSecretStringWo: .outputs.hasSecretStringWo}'
```{{exec}}

可以看到：`secretStringWo` 在 inputs 与 outputs 里**都是一段加密的 secret 密文**（开头那串 `4dabf181...` 是 Pulumi 给 secret 打的标记），**从不以明文落进 state**；`hasSecretStringWo: true` 则是一个布尔标志，表示「设置过只写值」。注意 inputs 与 outputs 里的密文并不相同，而且 provider 不会通过 API 把真实的只写值返回给你——这正是「只写」：**写得进云端，读不回明文**。

> 这一点与官方文档的 SSM `valueWo` 例子略有出入：文档里 SSM 的只写值在 outputs 中显示为 `null`，而这里 Secrets Manager 的 `secretStringWo` 在 outputs 中显示为一段加密占位密文。两者遵守同一条不变量：**只写值永远不会以明文进入 state，也无法从云端读回真实内容。**

接下来验证**版本字段的把控作用**。先试着只改值、不改版本号：

```bash
cp variants/step4-same-version.ts index.ts && \
pulumi preview
```{{exec}}

`secretStringWo` 的值变了，但 `secretStringWoVersion` 仍是 `1`——preview 显示**没有更新**（only-write 字段不参与普通 diff）。

现在递增版本号，再 preview，就会看到更新：

```bash
cp variants/step4-bumped.ts index.ts && \
pulumi up --yes
```{{exec}}

把 `secretStringWoVersion` 从 `1` 改成 `2`，Pulumi 才会把新的只写值重新下发到云端。

> 记住差异：**只写字段**在 state 里只以密文形式存在、真实值无法从云端读回、靠递增版本号触发更新；它主要为与底层 Terraform provider 的 schema 对齐而存在。**能用普通 secret 解决的，优先用 secret。**

> 另一个细节：`SecretVersion` 的 `secretId` 是「改动即重建」的属性——把同一个 version 指向另一个 secret 会触发资源替换，而非原地更新。本步全程指向同一个 `app-secret`，所以只会看到更新而非替换。
