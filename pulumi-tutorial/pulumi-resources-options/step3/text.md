# 隐式依赖与 dependsOn

Pulumi 的依赖图大多是**隐式**建立的：只要一个资源的参数引用了另一个资源的 Output，依赖关系就自动产生。少数没有数据引用、却仍需排序的场景，才用显式 `dependsOn`。

部署带依赖的版本：

```bash
cd /root/workspace && cp variants/step3.ts index.ts && pulumi up --yes
```{{exec}}

`step3.ts` 新增了两个 Bucket：

- `log-bucket`：tag 里写了 `linkedTo: data.bucket`，引用了 `data` 的 Output → 与 `data` 形成**隐式依赖**，Pulumi 保证 `data` 先就绪。
- `audit-bucket`：与 `log` 之间没有任何数据引用，但加了 `dependsOn: [log]` → **显式依赖**，强制在 `log` 之后创建。

从 state 里把依赖关系导出来看：

```bash
pulumi stack export | jq '.deployment.resources[] | select(.type=="aws:s3/bucket:Bucket") | {urn, dependencies}'
```{{exec}}

你会看到 `log-bucket` 的 `dependencies` 里含有 `data-bucket` 的 URN，`audit-bucket` 的 `dependencies` 里含有 `log-bucket` 的 URN。

经验法则：

- 能用数据引用（隐式依赖）就别手写 `dependsOn`——前者更准确、可维护。
- 只有当顺序约束**无法**通过参数表达时（例如「IAM 策略生效后再建实例」这种纯时序），才用 `dependsOn`。
