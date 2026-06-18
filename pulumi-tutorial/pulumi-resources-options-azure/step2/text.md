# auto-naming 与 deleteBeforeReplace

固定物理名的资源一旦需要 replace，就会撞名。先制造一次 replace 看问题，再用 `deleteBeforeReplace` 解决。

**1) 用 `replaceOnChanges` 把 tag 变化强制当成 replace**：

先看这一步要运行的代码：

```bash
cat /root/workspace/variants/step2-pre.ts
```{{exec}}

再应用它（这一步会**故意失败**）：

```bash
cd /root/workspace && cp variants/step2-pre.ts index.ts && pulumi up --yes
```{{exec}}

`step2-pre.ts` 给 `data-rg` 加了 `replaceOnChanges: ["tags"]` 并改了 tag，强制把这次 tag 变化当成一次替换。`up` 会先打印 `+-replace` 的计划，真正执行时却**报错失败**，错误大致如下：

```text
azure:core:ResourceGroup (data-rg):
  error: a resource with the ID ".../resourceGroups/resources-lab-data-rg" already exists ...
```

原因正是「固定物理名 + 默认的先建后删」：替换时 Pulumi 想先创建一个新的 `data-rg`，但它的物理名被写死成 `resources-lab-data-rg`，与正在被替换的旧资源同名，于是在**创建阶段**就撞名失败。旧资源仍原封不动留在 state 里，下一步我们用 `deleteBeforeReplace` 把顺序改成「先删后建」来解决。

**2) 加上 `deleteBeforeReplace: true`，改成先删后建**：

先看改动后的代码：

```bash
cat /root/workspace/variants/step2.ts
```{{exec}}

再应用它：

```bash
cp variants/step2.ts index.ts && pulumi up --yes
```{{exec}}

`step2.ts` 在同一资源上加了 `deleteBeforeReplace: true`。这次 Pulumi 先删除旧的 `resources-lab-data-rg`，再用新 tag 重建，避免了同名冲突。

```bash
pulumi stack export | jq '.deployment.resources[] | select(.type=="azure:core/resourceGroup:ResourceGroup") | {urn, physicalName: .outputs.name}'
```{{exec}}

要点：

- **auto-naming**（如 `media-rg`）天然支持「先建后删」的零停机替换，因为新旧物理名不同。
- **固定物理名**牺牲了这种灵活性，replace 时往往必须 `deleteBeforeReplace`，代价是中间存在短暂删除窗口。
- 因此除非有强约束（合规、命名规范、跨订阅引用），优先让 provider auto-name。
