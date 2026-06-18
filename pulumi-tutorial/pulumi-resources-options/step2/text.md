# auto-naming 与 deleteBeforeReplace

固定物理名的资源一旦需要 replace，就会撞名。先制造一次 replace 看问题，再用 `deleteBeforeReplace` 解决。

**1) 用 `replaceOnChanges` 把 tag 变化强制当成 replace**：

先看这一步要运行的代码：

```bash
cat /root/workspace/variants/step2-pre.ts
```{{exec}}

再应用它：

```bash
cd /root/workspace && cp variants/step2-pre.ts index.ts && pulumi preview
```{{exec}}

`step2-pre.ts` 给 `data-bucket` 加了 `replaceOnChanges: ["tags"]` 并改了 tag。预览里 `data-bucket` 会显示 `+-replace`，这是一份「先建后删」的替换**计划**。注意这里只是 `pulumi preview`，并未真正执行，所以**此刻看不到冲突**。同名冲突要等 `pulumi up` 真正执行时才会暴露：默认的「先建后删」会先去创建第二个物理名同为 `resources-lab-data` 的 Bucket，与现存的撞名。所以我们不直接应用这一版，而是下一步先补上 `deleteBeforeReplace` 再 up。

**2) 加上 `deleteBeforeReplace: true`，改成先删后建**：

先看改动后的代码：

```bash
cat /root/workspace/variants/step2.ts
```{{exec}}

再应用它：

```bash
cp variants/step2.ts index.ts && pulumi up --yes
```{{exec}}

`step2.ts` 在同一资源上加了 `deleteBeforeReplace: true`。这次 Pulumi 先删除旧的 `resources-lab-data`，再用新 tag 重建，避免了同名冲突。

```bash
pulumi stack export | jq '.deployment.resources[] | select(.type=="aws:s3/bucket:Bucket") | {urn, physicalName: .outputs.bucket}'
```{{exec}}

要点：

- **auto-naming**（如 `media-bucket`）天然支持「先建后删」的零停机替换，因为新旧物理名不同。
- **固定物理名**牺牲了这种灵活性，replace 时往往必须 `deleteBeforeReplace`，代价是中间存在短暂删除窗口。
- 因此除非有强约束（合规、跨账号引用），优先让 provider auto-name。