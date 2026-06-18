# Output→Input：依赖追踪与创建顺序

Pulumi 把命令式语言变成声明式，靠的就是一招：**把资源 A 的 Output 当作资源 B 的 Input 传过去时，自动记下「B 依赖 A」。**

先看代码：

```bash
cat /root/workspace/variants/step3.ts
```{{exec}}

部署：

```bash
cd /root/workspace && cp variants/step3.ts index.ts && pulumi up --yes
```{{exec}}

`step3.ts` 新增了两个 Resource Group：

- `log-rg`：tag 里写了 `linkedTo: dataRg.name`，引用了 `data` 的 Output → 与 `data` 形成**隐式依赖**，Pulumi 保证 `data` 先就绪；
- `audit-rg`：与 `log` 没有任何数据引用，但加了 `dependsOn: [logRg]` → **显式依赖**，强制在 `log` 之后创建。

从 state 里把依赖关系导出来看：

```bash
pulumi stack export | jq '.deployment.resources[] | select(.type=="azure:core/resourceGroup:ResourceGroup") | {urn, dependencies}'
```{{exec}}

你会看到 `log-rg` 的 `dependencies` 含有 `data-rg` 的 URN，`audit-rg` 的 `dependencies` 含有 `log-rg` 的 URN。

经验法则：

- 能用数据引用（隐式依赖）就别手写 `dependsOn`——前者更准确、可维护；
- 只有当顺序约束**无法**通过参数表达时（纯时序），才用 `dependsOn`。
