# Write-only 只写字段

前面讲的 secret 都是「加密后写进 state、需要时再解密读回」。还有另一类字段——**只写字段（write-only）**：能写进去，但云 API 永远不会把它读回来，因此 state 的 **outputs 里永远看不到它的值**。

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

现在看 state。只写字段的初始值会作为 **secret 写进 state 的 inputs**，但**绝不出现在 outputs 里**：

```bash
pulumi stack export | jq '.deployment.resources[] | select(.type=="aws:secretsmanager/secretVersion:SecretVersion") | {inputs_keys: (.inputs | keys), secretStringWo_in_outputs: .outputs.secretStringWo, hasSecretStringWo: .outputs.hasSecretStringWo}'
```{{exec}}

可以看到：`secretStringWo` 出现在 inputs 里（且是密文 secret），而 outputs 里的 `secretStringWo` 是 `null`，只有 `hasSecretStringWo: true` 告诉你「设置过只写值」。

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

> 记住差异：**只写字段**只进 inputs（作为 secret）、outputs 永远为空、靠递增版本号触发更新；它主要为与底层 Terraform provider 的 schema 对齐而存在。**能用普通 secret 解决的，优先用 secret。**

> 另一个细节：`SecretVersion` 的 `secretId` 是「改动即重建」的属性——把同一个 version 指向另一个 secret 会触发资源替换，而非原地更新。本步全程指向同一个 `app-secret`，所以只会看到更新而非替换。
