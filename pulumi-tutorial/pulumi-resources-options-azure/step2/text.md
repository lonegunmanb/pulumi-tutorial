# auto-naming 与 deleteBeforeReplace

固定物理名的资源一旦需要 replace，就会撞名。先制造一次 replace 看问题，再用 `deleteBeforeReplace` 解决。

**1) 用 `replaceOnChanges` 把 tag 变化强制当成 replace**：

```bash
cd /root/workspace && cp variants/step2-pre.ts index.ts && pulumi preview
```{{exec}}

`step2-pre.ts` 给 `data-rg` 加了 `replaceOnChanges: ["tags"]` 并改了 tag。预览里 `data-rg` 会显示 `+-replace`。由于它的物理名固定为 `resources-lab-data-rg`，默认的「先建后删」会与现存同名 Resource Group 冲突。

**2) 加上 `deleteBeforeReplace: true`，改成先删后建**：

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
