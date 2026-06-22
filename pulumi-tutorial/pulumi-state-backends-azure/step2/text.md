# 部署 dev Stack

先看当前 Pulumi 程序。它只创建一个随机名称资源，并导出几个 Stack Output。

```bash
cd /root/workspace/state-backends-azure && \
cat index.ts
```{{exec}}

创建 dev Stack，设置普通配置与机密配置，然后执行部署。

```bash
source /root/.pulumi-state-env.sh && \
cd /root/workspace/state-backends-azure && \
(pulumi stack select dev 2>/dev/null || pulumi stack init dev) && \
pulumi config set service catalog && \
pulumi config set owner platform-team && \
pulumi config set --secret operatorToken dev-token-123 && \
pulumi up --yes && \
pulumi stack output
```{{exec}}

部署完成后，当前 Stack 的 checkpoint 已经写入 Azure Blob Backend。现在直接下载这个 checkpoint，确认它不包含明文 token，并查看 operatorTokenPreview 对应的密文。

```bash
source /root/.pulumi-state-env.sh && \
cd /root/workspace/state-backends-azure && \
azlocal storage blob download --account pulumistate --container pulumi-state --name .pulumi/stacks/state-backends-azure/dev.json > dev-backend-state.json && \
if grep -q 'dev-token-123' dev-backend-state.json; then echo 'ERROR: found plaintext secret in backend state' && false; else echo 'OK: backend state does not contain plaintext dev-token-123'; fi && \
jq '(.deployment.resources // .checkpoint.latest.resources // []) as $resources | ($resources[] | select(.type=="pulumi:pulumi:Stack")) as $stack | {resourceCount: ($resources | length), operatorTokenPreviewState: $stack.outputs.operatorTokenPreview, operatorTokenPreviewCiphertext: ($stack.outputs.operatorTokenPreview.ciphertext // $stack.outputs.operatorTokenPreview.secure)}' dev-backend-state.json
```{{exec}}

如果输出中看到 OK，并且 operatorTokenPreviewCiphertext 有值，就说明 dev-token-123 已经以密文写入 State，而不是以明文写进容器。
